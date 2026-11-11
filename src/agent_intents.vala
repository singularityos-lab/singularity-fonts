namespace Singularity.Apps.Fonts {

    internal class FontsIntents : Object {

        private static string text(Json.Object args, string key) {
            return args.has_member(key) ? args.get_string_member(key).strip() : "";
        }

        private static string kind_id(Kind k) {
            switch (k) {
                case Kind.SERIF: return "serif";
                case Kind.MONO: return "mono";
                case Kind.DISPLAY: return "display";
                default: return "sans";
            }
        }

        private static Family? find(Catalog c, string name) {
            string want = name.casefold();
            foreach (var f in c.families) if (f.name.casefold() == want) return f;
            return null;
        }

        private static async void list(FontsApp app, Json.Object args, owned Singularity.AppIntentReply reply) {
            app.hold();
            var c = yield Catalog.load();
            string category = text(args, "category");
            int limit = args.has_member("limit") ? (int) args.get_int_member("limit").clamp(1, 500) : 100;
            var found = c.filter(category == "" ? "all" : category, text(args, "query"));
            var b = new Json.Builder();
            b.begin_object();
            b.set_member_name("total").add_int_value(found.size);
            b.set_member_name("families").begin_array();
            int n = 0;
            foreach (var f in found) {
                if (n++ == limit) break;
                b.begin_object();
                b.set_member_name("name").add_string_value(f.name);
                b.set_member_name("category").add_string_value(kind_id(f.kind));
                b.set_member_name("styles").add_int_value(f.faces.size);
                if (f.user) b.set_member_name("installed_by_you").add_boolean_value(true);
                b.end_object();
            }
            b.end_array();
            b.end_object();
            app.release();
            reply(b.get_root(), null);
        }

        private static async void family(FontsApp app, Json.Object args, owned Singularity.AppIntentReply reply) {
            app.hold();
            try {
                var c = yield Catalog.load();
                var f = find(c, text(args, "name"));
                if (f == null) throw new IOError.NOT_FOUND("no font family %s; see fonts_list", text(args, "name"));
                var b = new Json.Builder();
                b.begin_object();
                b.set_member_name("name").add_string_value(f.name);
                b.set_member_name("category").add_string_value(kind_id(f.kind));
                b.set_member_name("installed_by_you").add_boolean_value(f.user);
                b.set_member_name("faces").begin_array();
                foreach (var face in f.faces) {
                    b.begin_object();
                    b.set_member_name("style").add_string_value(face.style);
                    b.set_member_name("weight").add_int_value(pango_weight(face.weight));
                    b.set_member_name("italic").add_boolean_value(face.italic);
                    b.set_member_name("file").add_string_value(face.file);
                    b.end_object();
                }
                b.end_array();
                b.end_object();
                reply(b.get_root(), null);
            } catch (Error e) {
                reply(null, e);
            } finally {
                app.release();
            }
        }

        private static async void install(FontsApp app, Json.Object args, owned Singularity.AppIntentReply reply) {
            app.hold();
            try {
                string p = text(args, "path");
                if (p.has_prefix("~/")) p = Path.build_filename(Environment.get_home_dir(), p.substring(2));
                if (p == "" || !FileUtils.test(p, FileTest.IS_REGULAR)) throw new IOError.NOT_FOUND("no font file at %s", p);
                string? info = yield Catalog.query_family(p);
                if (info == null) throw new IOError.INVALID_DATA("%s is not a font file", Path.get_basename(p));
                string name = info.split("|")[0].strip();
                string installed = yield Catalog.install(File.new_for_path(p));
                var c = yield Catalog.load();
                var f = find(c, name);
                if (f == null || !f.user) throw new IOError.FAILED("%s was copied but the system does not list it yet", name);
                var b = new Json.Builder();
                b.begin_object();
                b.set_member_name("installed").add_string_value(f.name);
                b.set_member_name("file").add_string_value(installed);
                b.set_member_name("for").add_string_value("this account only");
                b.set_member_name("undo").add_string_value("fonts_remove with name " + f.name);
                b.end_object();
                reply(b.get_root(), null);
            } catch (Error e) {
                reply(null, e);
            } finally {
                app.release();
            }
        }

        private static async void remove(FontsApp app, Json.Object args, owned Singularity.AppIntentReply reply) {
            app.hold();
            try {
                var c = yield Catalog.load();
                var f = find(c, text(args, "name"));
                if (f == null) throw new IOError.NOT_FOUND("no font family %s", text(args, "name"));
                if (!f.user) throw new IOError.PERMISSION_DENIED("%s comes with the system and cannot be removed here", f.name);
                var files = new Gee.ArrayList<string>();
                foreach (var face in f.faces) if (face.file.has_prefix(Catalog.user_dir() + "/")) files.add(face.file);
                yield Catalog.remove(f);
                var after = find(yield Catalog.load(), f.name);
                if (after != null && after.user) throw new IOError.FAILED("%s is still installed", f.name);
                var b = new Json.Builder();
                b.begin_object();
                b.set_member_name("removed").add_string_value(f.name);
                b.set_member_name("moved_to_trash").begin_array();
                foreach (string s in files) b.add_string_value(s);
                b.end_array();
                b.set_member_name("undo").add_string_value("restore the files from the Trash, then fonts_install each of them");
                b.end_object();
                reply(b.get_root(), null);
            } catch (Error e) {
                reply(null, e);
            } finally {
                app.release();
            }
        }

        internal static void install_intents(FontsApp app) {
            var agent = app.agent;
            agent.add_async_intent("fonts_list", "Font families on this computer, optionally by category (sans, serif, mono, display, user for the ones the person installed) or name.",
                "{\"type\":\"object\",\"properties\":{\"category\":{\"type\":\"string\",\"enum\":[\"all\",\"sans\",\"serif\",\"mono\",\"display\",\"user\"]},\"query\":{\"type\":\"string\"},\"limit\":{\"type\":\"integer\"}}}",
                Singularity.AppIntentRisk.READ, (args, reply) => {
                    list.begin(app, args, (owned) reply);
                });
            agent.add_async_intent("fonts_family", "The styles of one font family, with weight, italic and file.",
                "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}",
                Singularity.AppIntentRisk.READ, (args, reply) => {
                    family.begin(app, args, (owned) reply);
                });
            agent.add_async_intent("fonts_install", "Install a font file (.ttf, .otf, .woff) for this account.",
                "{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"}},\"required\":[\"path\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args, reply) => {
                    install.begin(app, args, (owned) reply);
                });
            agent.add_async_intent("fonts_remove", "Remove a font family the person installed; its files go to the Trash.",
                "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args, reply) => {
                    remove.begin(app, args, (owned) reply);
                });
        }
    }
}
