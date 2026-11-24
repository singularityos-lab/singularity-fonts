using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Fonts {

    public static void apply_font (Label label, string family, int fc_weight, bool italic, int size_pt) {
        var desc = new Pango.FontDescription ();
        desc.set_family (family);
        desc.set_weight ((Pango.Weight) pango_weight (fc_weight));
        desc.set_style (italic ? Pango.Style.ITALIC : Pango.Style.NORMAL);
        desc.set_size (size_pt * Pango.SCALE);
        var attrs = new Pango.AttrList ();
        attrs.insert (new Pango.AttrFontDesc (desc));
        label.attributes = attrs;
    }

    public class FontsWindow : Singularity.Widgets.Window {
        private struct Category {
            public string id;
            public string label;
            public string icon;
        }

        private FontsApp app;
        private Catalog catalog = new Catalog ();
        private AppSidebar sidebar;
        private Gee.HashMap<string, SidebarRow> rows = new Gee.HashMap<string, SidebarRow> ();
        private string current = "all";
        private string query = "";
        private GLib.ListStore store;
        private SingleSelection selection;
        private GridView grid;
        private Stack stack;
        private StatusPage empty;
        private SearchBubble search;
        private Label title;
        private Label subtitle;
        private Revealer panel_revealer;
        private Label detail_name;
        private Label detail_meta;
        private Entry sample_entry;
        private Box sizes_box;
        private Box styles_box;
        private Button remove_button;
        private Button install_button;
        private Family? shown = null;
        private File? pending_file = null;
        private string? pending_name = null;
        private bool ready = false;

        private signal void catalog_loaded ();

        public FontsWindow (FontsApp app) {
            Object (application: app);
            this.app = app;
            set_default_size (1100, 740);
            set_title (_("Fonts"));

            sidebar = new AppSidebar (220);
            set_sidebar (sidebar);
            set_sidebar_visible (true);
            build_sidebar ();

            search = add_bubble_search (_("Search Fonts"), (text) => {
                if (text == query) return;
                query = text;
                refresh ();
            });
            search.entry.input_hints = InputHints.NO_SPELLCHECK;
            add_bubble_icon ("list-add-symbolic", _("Install Font File"), () => choose_file ());

            var content = new Box (Orientation.HORIZONTAL, 0);
            var main = new Box (Orientation.VERTICAL, 0);
            main.hexpand = true;
            var header = new Box (Orientation.VERTICAL, 2);
            header.margin_start = 24;
            header.margin_end = 24;
            header.margin_bottom = 10;
            header.margin_top = 16;
            Singularity.Widgets.apply_view_edge (header);
            title = new Label ("");
            title.xalign = 0;
            title.add_css_class ("title-2");
            subtitle = new Label ("");
            subtitle.xalign = 0;
            subtitle.add_css_class ("dim-label");
            header.append (title);
            header.append (subtitle);
            main.append (header);

            store = new GLib.ListStore (typeof (Family));
            selection = new SingleSelection (store);
            selection.autoselect = false;
            selection.can_unselect = true;
            selection.selected = Gtk.INVALID_LIST_POSITION;
            selection.notify["selected"].connect (() => {
                var fam = selection.selected_item as Family;
                if (fam != null) show_family (fam, null);
                else if (pending_file == null) panel_revealer.reveal_child = false;
                sync_actions ();
            });
            var factory = new SignalListItemFactory ();
            factory.setup.connect ((obj) => {
                var li = (ListItem) obj;
                var card = new Box (Orientation.VERTICAL, 6);
                card.add_css_class ("fonts-card");
                card.set_size_request (168, 128);
                var sample = new Label ("Aa");
                sample.add_css_class ("fonts-card-sample");
                sample.vexpand = true;
                sample.ellipsize = Pango.EllipsizeMode.END;
                var name = new Label ("");
                name.ellipsize = Pango.EllipsizeMode.END;
                name.max_width_chars = 18;
                var styles = new Label ("");
                styles.add_css_class ("dim-label");
                styles.add_css_class ("caption");
                card.append (sample);
                card.append (name);
                card.append (styles);
                li.child = card;
            });
            factory.bind.connect ((obj) => {
                var li = (ListItem) obj;
                var fam = (Family) li.item;
                var card = (Box) li.child;
                var sample = (Label) card.get_first_child ();
                var name = (Label) sample.get_next_sibling ();
                var styles = (Label) name.get_next_sibling ();
                var regular = fam.faces.size > 0 ? fam.faces[0] : null;
                foreach (var f in fam.faces) {
                    if (!f.italic && f.weight == 80) {
                        regular = f;
                        break;
                    }
                }
                apply_font (sample, fam.name, regular != null ? regular.weight : 80, regular != null && regular.italic, 30);
                name.label = fam.name;
                styles.label = fam.styles_label ();
            });
            grid = new GridView (selection, factory);
            grid.add_css_class ("fonts-grid");
            grid.max_columns = 12;
            grid.min_columns = 1;
            var scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.vexpand = true;
            scroll.child = grid;

            empty = new StatusPage ();
            empty.icon_name = "system-search";
            empty.title = _("No Fonts Found");
            empty.description = _("Try another name.");
            var clear = new Button.with_label (_("Clear Search"));
            clear.add_css_class ("pill");
            clear.add_css_class ("suggested-action");
            clear.halign = Align.CENTER;
            clear.clicked.connect (() => search.clear ());
            empty.child = clear;
            var none = new WelcomePage ();
            none.is_section = true;
            none.app_icon_name = "dev.sinty.fonts";
            none.title = _("No Fonts Installed Yet");
            none.subtitle = _("Fonts you install are only for your account. You can also drop a .ttf or .otf file here.");
            none.add_action ("font-x-generic", _("Install Font File"), _("Choose a .ttf, .otf or .woff file"), () => choose_file ());
            none.add_action ("computer", _("Browse All Fonts"), _("See the fonts already on this computer"), () => {
                current = "all";
                refresh ();
            });
            stack = new Stack ();
            stack.transition_type = StackTransitionType.CROSSFADE;
            stack.add_named (scroll, "grid");
            stack.add_named (empty, "empty");
            stack.add_named (none, "none");
            main.append (stack);
            content.append (main);

            panel_revealer = new Revealer ();
            panel_revealer.transition_type = RevealerTransitionType.SLIDE_LEFT;
            panel_revealer.child = build_panel ();
            panel_revealer.hexpand = false;
            panel_revealer.visible = false;
            panel_revealer.notify["child-revealed"].connect (() => {
                if (!panel_revealer.reveal_child && !panel_revealer.child_revealed) panel_revealer.visible = false;
            });
            content.append (panel_revealer);
            set_content (content);

            var drop = new DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
            drop.drop.connect ((value, x, y) => {
                var list = (Gdk.FileList) value.get_boxed ();
                foreach (var file in list.get_files ()) {
                    preview_file (file);
                    break;
                }
                return true;
            });
            ((Widget) this).add_controller (drop);

            var keys = new EventControllerKey ();
            keys.key_pressed.connect ((keyval, code, state) => {
                if (keyval == Gdk.Key.Escape && panel_revealer.reveal_child) {
                    close_panel ();
                    return true;
                }
                return false;
            });
            ((Widget) this).add_controller (keys);

            install_actions (search);
            reload.begin ();
        }

        private void install_actions (SearchBubble search) {
            add_simple ("open", () => choose_file ());
            add_simple ("install", () => install_pending.begin ());
            add_simple ("remove", () => confirm_remove ());
            add_simple ("copy-name", () => {
                if (shown != null) get_clipboard ().set_text (shown.name);
            });
            add_simple ("find", () => search.grab_focus_entry ());
            add_simple ("close-preview", () => close_panel ());
            add_simple ("toggle-sidebar", () => set_sidebar_visible (!get_sidebar_visible ()));
            add_simple ("close", () => close ());
            var collection = new SimpleAction.stateful ("collection", VariantType.STRING, new Variant.string (current));
            collection.activate.connect ((v) => {
                current = v.get_string ();
                refresh ();
            });
            add_action (collection);
            sync_actions ();
        }

        private void add_simple (string name, owned Callback cb) {
            var a = new SimpleAction (name, null);
            a.activate.connect (() => cb ());
            add_action (a);
        }

        private delegate void Callback ();

        private void sync_actions () {
            bool open = panel_revealer.reveal_child;
            enable ("install", pending_file != null && install_button.sensitive);
            enable ("remove", open && pending_file == null && shown != null && shown.user);
            enable ("copy-name", open && shown != null);
            enable ("close-preview", open);
            var collection = lookup_action ("collection") as SimpleAction;
            if (collection != null) collection.set_state (new Variant.string (current));
        }

        private void enable (string name, bool on) {
            var a = lookup_action (name) as SimpleAction;
            if (a != null) a.set_enabled (on);
        }

        private Category[] categories () {
            return {
                { "all", _("All Fonts"), "font-x-generic-symbolic" },
                { "sans", _("Sans Serif"), "fonts-sans-symbolic" },
                { "serif", _("Serif"), "fonts-serif-symbolic" },
                { "mono", _("Monospace"), "fonts-mono-symbolic" },
                { "display", _("Display & Handwriting"), "fonts-display-symbolic" },
                { "user", _("Installed by You"), "user-home-symbolic" }
            };
        }

        private void build_sidebar () {
            var cats = categories ();
            sidebar.box.append (new SidebarSectionLabel (_("Collections")));
            for (int i = 0; i < cats.length; i++) {
                if (i == 5) sidebar.box.append (new SidebarSectionLabel (_("Yours")));
                var row = new SidebarRow (cats[i].icon, cats[i].label);
                string id = cats[i].id;
                row.clicked.connect (() => {
                    current = id;
                    refresh ();
                });
                rows[id] = row;
                sidebar.box.append (row);
            }
        }

        public async void reload () {
            catalog = yield Catalog.load ();
            ready = true;
            refresh ();
            catalog_loaded ();
        }

        public Variant save_migration () {
            var d = new VariantDict ();
            d.insert_value ("collection", new Variant.string (current));
            d.insert_value ("query", new Variant.string (query));
            if (pending_file != null) d.insert_value ("preview", new Variant.string (Singularity.Migration.portable_path (pending_file)));
            else if (shown != null && panel_revealer.reveal_child) d.insert_value ("family", new Variant.string (shown.name));
            return d.end ();
        }

        public string[] migration_files () {
            if (pending_file == null) return {};
            return { Singularity.Migration.portable_path (pending_file) };
        }

        public async void restore_migration (Variant data) {
            var d = new VariantDict (data);
            var collection = d.lookup_value ("collection", VariantType.STRING);
            if (collection != null && rows.has_key (collection.get_string ())) current = collection.get_string ();
            var text = d.lookup_value ("query", VariantType.STRING);
            query = text != null ? text.get_string () : "";
            search.entry.text = query;
            var family = d.lookup_value ("family", VariantType.STRING);
            if (family != null) pending_name = family.get_string ();
            if (ready) {
                refresh ();
            } else {
                ulong id = catalog_loaded.connect (() => restore_migration.callback ());
                yield;
                disconnect (id);
            }
            var preview = d.lookup_value ("preview", VariantType.STRING);
            if (preview != null) yield preview_file_async (Singularity.Migration.local_file (preview.get_string ()));
        }

        public void show_named (string name) {
            pending_name = name;
            current = "all";
            query = "";
            if (catalog.families.size > 0) refresh ();
        }

        private void select_pending () {
            if (pending_name == null) return;
            for (uint i = 0; i < store.get_n_items (); i++) {
                if (((Family) store.get_item (i)).name == pending_name) {
                    pending_name = null;
                    selection.selected = i;
                    grid.scroll_to (i, ListScrollFlags.FOCUS, null);
                    return;
                }
            }
        }

        private string label_for (string id) {
            foreach (var c in categories ()) if (c.id == id) return c.label;
            return "";
        }

        private void refresh () {
            foreach (var e in rows.entries) e.value.set_active (e.key == current);
            sync_actions ();
            var items = catalog.filter (current, query);
            title.label = query.strip () != "" ? _("Results") : label_for (current);
            subtitle.label = ngettext ("%d family", "%d families", items.size).printf (items.size);
            selection.selected = Gtk.INVALID_LIST_POSITION;
            store.remove_all ();
            var array = new Object[items.size];
            for (int i = 0; i < items.size; i++) array[i] = items[i];
            store.splice (0, 0, array);
            if (items.size == 0 && query.strip () == "" && current == "user") {
                stack.visible_child_name = "none";
            } else if (items.size == 0) {
                bool searching = query.strip () != "";
                empty.title = searching ? _("No Fonts Found") : _("No Fonts in This Collection");
                empty.description = searching ? _("Try another name.") : "";
                empty.child.visible = searching;
                stack.visible_child_name = "empty";
            } else {
                stack.visible_child_name = "grid";
            }
            select_pending ();
        }

        private Widget build_panel () {
            var outer = new Box (Orientation.VERTICAL, 0);
            outer.set_size_request (340, -1);
            outer.margin_end = 16;
            outer.margin_bottom = 16;
            Singularity.Widgets.apply_view_edge (outer);
            var panel = new Box (Orientation.VERTICAL, 12);
            panel.add_css_class ("fonts-panel");
            panel.vexpand = true;

            var top = new Box (Orientation.HORIZONTAL, 8);
            var names = new Box (Orientation.VERTICAL, 2);
            names.hexpand = true;
            detail_name = new Label ("");
            detail_name.xalign = 0;
            detail_name.wrap = true;
            detail_name.add_css_class ("title-3");
            detail_meta = new Label ("");
            detail_meta.xalign = 0;
            detail_meta.add_css_class ("dim-label");
            names.append (detail_name);
            names.append (detail_meta);
            top.append (names);
            var close = new Button.from_icon_name ("window-close-symbolic");
            close.add_css_class ("flat");
            close.add_css_class ("circular");
            close.valign = Align.START;
            close.tooltip_text = _("Close");
            close.clicked.connect (close_panel);
            top.append (close);
            panel.append (top);

            sample_entry = new Entry ();
            sample_entry.text = app.settings.get_string ("sample-text");
            sample_entry.placeholder_text = _("Type to preview");
            sample_entry.changed.connect (() => {
                app.settings.set_string ("sample-text", sample_entry.text);
                if (shown != null) fill_samples (shown);
            });
            panel.append (sample_entry);

            var scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.vexpand = true;
            var inner = new Box (Orientation.VERTICAL, 14);
            sizes_box = new Box (Orientation.VERTICAL, 10);
            inner.append (sizes_box);
            var styles_title = new Label (_("Styles"));
            styles_title.xalign = 0;
            styles_title.add_css_class ("heading");
            styles_title.margin_top = 6;
            inner.append (styles_title);
            styles_box = new Box (Orientation.VERTICAL, 6);
            inner.append (styles_box);
            scroll.child = inner;
            panel.append (scroll);

            install_button = new Button.with_label (_("Install"));
            install_button.add_css_class ("suggested-action");
            install_button.add_css_class ("pill");
            install_button.clicked.connect (() => install_pending.begin ());
            panel.append (install_button);
            remove_button = new Button.with_label (_("Remove Font"));
            remove_button.add_css_class ("flat");
            remove_button.clicked.connect (confirm_remove);
            panel.append (remove_button);
            outer.append (panel);
            return outer;
        }

        private void close_panel () {
            pending_file = null;
            selection.selected = Gtk.INVALID_LIST_POSITION;
            panel_revealer.reveal_child = false;
            sync_actions ();
        }

        private string sample_text () {
            string t = sample_entry.text.strip ();
            return t != "" ? t : _("The quick brown fox jumps over the lazy dog");
        }

        private void fill_samples (Family fam) {
            Widget? child;
            while ((child = sizes_box.get_first_child ()) != null) sizes_box.remove (child);
            var face = fam.faces.size > 0 ? fam.faces[0] : null;
            foreach (var f in fam.faces) if (!f.italic && f.weight == 80) face = f;
            foreach (int size in new int[] { 12, 16, 22, 30, 40 }) {
                var row = new Box (Orientation.VERTICAL, 0);
                var tag = new Label ("%d pt".printf (size));
                tag.xalign = 0;
                tag.add_css_class ("dim-label");
                tag.add_css_class ("caption");
                row.append (tag);
                var l = new Label (sample_text ());
                l.xalign = 0;
                l.wrap = true;
                l.wrap_mode = Pango.WrapMode.WORD_CHAR;
                l.selectable = true;
                apply_font (l, fam.name, face != null ? face.weight : 80, face != null && face.italic, size);
                row.append (l);
                sizes_box.append (row);
            }
            while ((child = styles_box.get_first_child ()) != null) styles_box.remove (child);
            foreach (var f in fam.faces) {
                var row = new Box (Orientation.HORIZONTAL, 10);
                row.add_css_class ("fonts-style-row");
                var l = new Label (f.style);
                l.xalign = 0;
                l.hexpand = true;
                l.ellipsize = Pango.EllipsizeMode.END;
                apply_font (l, fam.name, f.weight, f.italic, 15);
                row.append (l);
                var ext = new Label (Path.get_basename (f.file));
                ext.add_css_class ("dim-label");
                ext.add_css_class ("caption");
                ext.ellipsize = Pango.EllipsizeMode.MIDDLE;
                ext.max_width_chars = 18;
                ext.tooltip_text = f.file;
                row.append (ext);
                styles_box.append (row);
            }
        }

        private void show_family (Family fam, File? file) {
            shown = fam;
            pending_file = file;
            detail_name.label = fam.name;
            string where = file != null ? _("Not installed") : (fam.user ? _("Installed by you") : _("Installed for everyone"));
            detail_meta.label = "%s · %s · %s".printf (fam.kind.label (), fam.styles_label (), where);
            fill_samples (fam);
            install_button.visible = file != null;
            remove_button.visible = file == null && fam.user;
            panel_revealer.visible = true;
            panel_revealer.reveal_child = true;
            sync_actions ();
        }

        private void choose_file () {
            var dialog = new FileDialog ();
            dialog.title = _("Choose a Font File");
            var filter = new FileFilter ();
            filter.name = _("Font Files");
            foreach (string s in new string[] { "ttf", "otf", "ttc", "woff", "woff2", "pfb" }) filter.add_suffix (s);
            filter.add_mime_type ("font/ttf");
            filter.add_mime_type ("font/otf");
            var filters = new GLib.ListStore (typeof (FileFilter));
            filters.append (filter);
            dialog.filters = filters;
            dialog.open.begin (this, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file != null) preview_file (file);
                } catch (Error e) {
                }
            });
        }

        public void preview_file (File file) {
            preview_file_async.begin (file);
        }

        private async void preview_file_async (File file) {
            string? path = file.get_path ();
            if (path == null) return;
            string? info = yield Catalog.query_family (path);
            if (info == null) {
                show_error (_("Not a Font"), _("\"%s\" could not be read as a font file.").printf (file.get_basename ()));
                return;
            }
            try {
                font_map_add_font_file (Pango.CairoFontMap.get_default (), path);
            } catch (Error e) {
                warning ("Preview font failed: %s", e.message);
            }
            var parts = info.split ("|");
            var fam = new Family (parts[0]);
            fam.kind = Catalog.classify (parts[0], 0);
            fam.faces.add (new Face (parts.length > 1 && parts[1] != "" ? parts[1] : "Regular", path, 80, parts.length > 1 && parts[1].down ().contains ("italic")));
            selection.selected = Gtk.INVALID_LIST_POSITION;
            show_family (fam, file);
        }

        private async void install_pending () {
            if (pending_file == null) return;
            install_button.sensitive = false;
            sync_actions ();
            try {
                yield Catalog.install (pending_file);
                string name = shown != null ? shown.name : "";
                pending_file = null;
                yield reload ();
                current = "user";
                refresh ();
                for (uint i = 0; i < store.get_n_items (); i++) {
                    if (((Family) store.get_item (i)).name == name) {
                        selection.selected = i;
                        break;
                    }
                }
            } catch (Error e) {
                show_error (_("Could Not Install"), e.message);
            }
            install_button.sensitive = true;
            sync_actions ();
        }

        private void confirm_remove () {
            if (shown == null) return;
            var fam = shown;
            var dlg = new ConfirmDialog (app, _("Remove Font?"), "user-trash-symbolic",
                _("\"%s\" will be moved to the Trash. Documents using it will show another font.").printf (fam.name),
                _("Remove"), ConfirmDialog.ActionStyle.DESTRUCTIVE);
            dlg.transient_for = this;
            dlg.response.connect ((r) => {
                if (r != ConfirmDialog.Response.PRIMARY) return;
                Catalog.remove.begin (fam, (obj, res) => {
                    try {
                        Catalog.remove.end (res);
                        close_panel ();
                        reload.begin ();
                    } catch (Error e) {
                        show_error (_("Could Not Remove"), e.message);
                    }
                });
            });
            dlg.present ();
        }

        private void show_error (string title, string message) {
            var dlg = new ConfirmDialog.message (app, title, "dialog-error-symbolic", message, _("Close"));
            dlg.transient_for = this;
            dlg.present ();
        }
    }
}
