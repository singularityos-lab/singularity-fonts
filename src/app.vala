using Gtk;

namespace Singularity.Apps.Fonts {

    public class FontsApp : Singularity.Application, Singularity.Migration.Migratable {
        public GLib.Settings settings { get; private set; }
        private bool install_pending;

        public FontsApp () {
            Object (application_id: "dev.sinty.fonts", flags: ApplicationFlags.HANDLES_OPEN);
            add_main_option ("install", 0, OptionFlags.NONE, OptionArg.NONE, _("Choose a font file to install"), null);
        }

        protected override int handle_local_options (VariantDict options) {
            if (!options.contains ("install")) return -1;
            try {
                register (null);
            } catch (Error e) {
                warning ("fonts: %s", e.message);
                return 1;
            }
            if (get_is_remote ()) {
                activate_action ("choose-font", null);
                return 0;
            }
            install_pending = true;
            return -1;
        }

        protected override void startup () {
            base.startup ();
            FontsIntents.install_intents (this);
            settings = new GLib.Settings ("dev.sinty.fonts");
            IconTheme.get_for_display (Gdk.Display.get_default ()).add_resource_path ("/dev/sinty/fonts/icons");
            var provider = new CssProvider ();
            provider.load_from_string (CSS);
            StyleContext.add_provider_for_display (Gdk.Display.get_default (), provider, STYLE_PROVIDER_PRIORITY_USER + 1);
            var menu = new GLib.Menu ();
            var file_menu = new GLib.Menu ();
            var f1 = new GLib.Menu ();
            f1.append (_("Open Font File…"), "win.open");
            f1.append (_("Install Font"), "win.install");
            file_menu.append_section (null, f1);
            var f2 = new GLib.Menu ();
            f2.append (_("Close Window"), "win.close");
            f2.append (_("Quit"), "app.quit");
            file_menu.append_section (null, f2);
            menu.append_submenu (_("File"), file_menu);
            var edit_menu = new GLib.Menu ();
            var e1 = new GLib.Menu ();
            e1.append (_("Copy Font Name"), "win.copy-name");
            e1.append (_("Remove Font…"), "win.remove");
            edit_menu.append_section (null, e1);
            var e2 = new GLib.Menu ();
            e2.append (_("Find"), "win.find");
            edit_menu.append_section (null, e2);
            var e3 = new GLib.Menu ();
            e3.append (_("Settings"), "app.settings");
            edit_menu.append_section (null, e3);
            menu.append_submenu (_("Edit"), edit_menu);
            var view_menu = new GLib.Menu ();
            var v1 = new GLib.Menu ();
            string[,] collections = {
                { "all", _("All Fonts") },
                { "sans", _("Sans Serif") },
                { "serif", _("Serif") },
                { "mono", _("Monospace") },
                { "display", _("Display and Handwriting") },
                { "user", _("Installed by You") }
            };
            for (int i = 0; i < collections.length[0]; i++) {
                var item = new GLib.MenuItem (collections[i, 1], null);
                item.set_action_and_target_value ("win.collection", new Variant.string (collections[i, 0]));
                v1.append_item (item);
                set_accels_for_action ("win.collection::" + collections[i, 0], { "<Control>%d".printf (i + 1) });
            }
            view_menu.append_section (null, v1);
            var v2 = new GLib.Menu ();
            v2.append (_("Close Preview"), "win.close-preview");
            v2.append (_("Toggle Sidebar"), "win.toggle-sidebar");
            view_menu.append_section (null, v2);
            menu.append_submenu (_("View"), view_menu);
            set_menubar (menu);
            var quit_action = new SimpleAction ("quit", null);
            quit_action.activate.connect (() => quit ());
            add_action (quit_action);
            var settings_action = new SimpleAction ("settings", null);
            settings_action.activate.connect (() => {
                try {
                    Singularity.Shell.ShellService shell = Bus.get_proxy_sync (BusType.SESSION, "dev.sinty.desktop", "/dev/sinty/Shell");
                    shell.open_app_settings ("dev.sinty.fonts");
                } catch (Error e) {
                    warning ("Failed to open settings: %s", e.message);
                }
            });
            add_action (settings_action);
            var choose_action = new SimpleAction ("choose-font", null);
            choose_action.activate.connect (() => {
                ((GLib.ActionGroup) ensure_window ()).activate_action ("open", null);
            });
            add_action (choose_action);
            var install_action = new SimpleAction ("install-font", new VariantType ("as"));
            install_action.activate.connect ((param) => {
                File[] files = {};
                foreach (string uri in param.get_strv ()) files += File.new_for_uri (uri);
                install_files.begin (files);
            });
            add_action (install_action);
            var show_action = new SimpleAction ("show-family", VariantType.STRING);
            show_action.activate.connect ((param) => show_family (param.get_string ()));
            add_action (show_action);
            set_accels_for_action ("app.quit", { "<Control>q" });
            set_accels_for_action ("app.settings", { "<Control>comma" });
            set_accels_for_action ("win.close", { "<Control>w" });
            set_accels_for_action ("win.open", { "<Control>o" });
            set_accels_for_action ("win.find", { "<Control>f" });
            set_accels_for_action ("win.copy-name", { "<Control><Shift>c" });
            set_accels_for_action ("win.remove", { "<Control>Delete" });
            set_accels_for_action ("win.toggle-sidebar", { "F9" });
        }

        private FontsWindow ensure_window () {
            var window = get_active_window () as FontsWindow;
            if (window == null) window = new FontsWindow (this);
            window.present ();
            return window;
        }

        public override void activate () {
            var window = ensure_window ();
            if (install_pending) {
                install_pending = false;
                ((GLib.ActionGroup) window).activate_action ("open", null);
            }
        }

        public Variant save_model () {
            return new VariantDict ().end ();
        }

        public async void restore_model (Variant model) throws Error {
        }

        public string window_kind (Gtk.Window w) {
            return (w is FontsWindow) ? "fonts" : "";
        }

        public Variant save_window (Gtk.Window w) {
            return ((FontsWindow) w).save_migration ();
        }

        public string[] files () {
            string[] found = {};
            foreach (var w in get_windows ()) {
                if (w is FontsWindow) {
                    foreach (string f in ((FontsWindow) w).migration_files ()) found += f;
                }
            }
            return found;
        }

        public async Gtk.Window? rebuild_window (string kind, Variant data) throws Error {
            if (kind != "fonts") return null;
            var window = new FontsWindow (this);
            yield window.restore_migration (data);
            return window;
        }

        public void show_family (string name) {
            ensure_window ().show_named (name);
        }

        private async void install_files (File[] files) {
            hold ();
            string[] installed = {};
            string[] failed = {};
            foreach (var file in files) {
                string? path = file.get_path ();
                string? info = path != null ? yield Catalog.query_family (path) : null;
                if (info == null) {
                    failed += file.get_basename ();
                    continue;
                }
                try {
                    yield Catalog.install (file);
                    installed += info.split ("|")[0];
                } catch (Error e) {
                    failed += "%s (%s)".printf (file.get_basename (), e.message);
                }
            }
            if (installed.length > 0) {
                var n = new GLib.Notification (ngettext ("Font Installed", "Fonts Installed", installed.length));
                n.set_body (string.joinv (", ", installed));
                n.set_default_action_and_target_value ("app.show-family", new Variant.string (installed[0]));
                send_notification ("install", n);
                var window = get_active_window () as FontsWindow;
                if (window != null) window.reload.begin ();
            }
            if (failed.length > 0) {
                var n = new GLib.Notification (_("Could Not Install"));
                n.set_body (string.joinv (", ", failed));
                send_notification ("install-failed", n);
            }
            release ();
        }

        public override void open (File[] files, string hint) {
            var window = ensure_window ();
            if (files.length > 0) window.preview_file (files[0]);
        }

        private const string CSS = """
.fonts-grid {
    background: transparent;
    padding: 0 18px 18px 18px;
}

.fonts-grid > child {
    padding: 0;
    margin: 5px;
    border-radius: 16px;
}

.fonts-card {
    padding: 12px;
    border-radius: 16px;
    background-color: alpha(@window_fg_color, 0.05);
    transition: background-color 120ms ease;
}

.fonts-grid > child:hover .fonts-card {
    background-color: alpha(@window_fg_color, 0.09);
}

.fonts-grid > child:selected .fonts-card {
    background-color: alpha(@accent_bg_color, 0.2);
}

.fonts-grid > child:selected {
    background: transparent;
    color: inherit;
}

.fonts-panel {
    padding: 18px;
    border-radius: 20px;
    background-color: alpha(@window_fg_color, 0.05);
}

.fonts-style-row {
    padding: 8px 10px;
    border-radius: 10px;
    background-color: @view_bg_color;
}
""";
    }

    public static int main (string[] args) {
        Intl.setlocale (LocaleCategory.ALL, "");
        string locale_dir = "/usr/share/locale";
        try {
            string exe = FileUtils.read_link ("/proc/self/exe");
            locale_dir = Path.build_filename (Path.get_dirname (Path.get_dirname (exe)), "share", "locale");
        } catch (Error e) {
        }
        Intl.bindtextdomain ("singularity-fonts", locale_dir);
        Intl.bind_textdomain_codeset ("singularity-fonts", "UTF-8");
        Intl.textdomain ("singularity-fonts");
        Environment.set_application_name (_("Fonts"));
        var app = new FontsApp ();
        new FontsSearch (app).export (app);
        return app.run (args);
    }
}
