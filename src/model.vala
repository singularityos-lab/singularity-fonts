namespace Singularity.Apps.Fonts {

    public static int pango_weight (int fc) {
        if (fc <= 0) return 100;
        if (fc <= 40) return 200;
        if (fc <= 50) return 300;
        if (fc <= 80) return 400;
        if (fc <= 100) return 500;
        if (fc <= 180) return 600;
        if (fc <= 200) return 700;
        if (fc <= 205) return 800;
        return 900;
    }

    public enum Kind {
        SANS,
        SERIF,
        MONO,
        DISPLAY;

        public string label () {
            switch (this) {
                case SERIF: return _("Serif");
                case MONO: return _("Monospace");
                case DISPLAY: return _("Display & Handwriting");
                default: return _("Sans Serif");
            }
        }
    }

    public class Face : Object {
        public string style;
        public string file;
        public int weight;
        public bool italic;

        public Face (string style, string file, int weight, bool italic) {
            this.style = style;
            this.file = file;
            this.weight = weight;
            this.italic = italic;
        }
    }

    public class Family : Object {
        public string name;
        public Kind kind = Kind.SANS;
        public bool user = false;
        public Gee.ArrayList<Face> faces = new Gee.ArrayList<Face> ();
        public Gee.HashSet<string> files = new Gee.HashSet<string> ();

        public Family (string name) {
            this.name = name;
        }

        public string styles_label () {
            return ngettext ("%d style", "%d styles", faces.size).printf (faces.size);
        }

        public void sort_faces () {
            faces.sort ((a, b) => {
                if (a.italic != b.italic) return a.italic ? 1 : -1;
                return a.weight - b.weight;
            });
        }
    }

    public class Catalog : Object {
        public Gee.ArrayList<Family> families = new Gee.ArrayList<Family> ();

        public static string user_dir () {
            return Path.build_filename (Environment.get_user_data_dir (), "fonts");
        }

        private static string[] DISPLAY_WORDS = {
            "script", "hand", "brush", "comic", "display", "marker", "graffiti", "cursive",
            "calligraph", "decorative", "pacifico", "lobster", "dancing", "caveat", "chancery", "fraktur"
        };

        public static Kind classify (string family, int spacing) {
            string f = family.down ();
            if (spacing >= 90 || f.contains ("mono") || f.contains ("code") || f.contains ("courier") || f.contains ("console")) return Kind.MONO;
            foreach (string w in DISPLAY_WORDS) if (f.contains (w)) return Kind.DISPLAY;
            if (f.contains ("sans")) return Kind.SANS;
            if (f.contains ("serif") || f.contains ("roman") || f.contains ("times") || f.contains ("georgia")
                || f.contains ("garamond") || f.contains ("baskerville") || f.contains ("bodoni") || f.contains ("caslon")
                || f.contains ("slab") || f.contains ("book") || f.contains ("merriweather") || f.contains ("playfair")) return Kind.SERIF;
            return Kind.SANS;
        }

        public static Catalog parse (string text, string user_root) {
            var c = new Catalog ();
            var map = new Gee.HashMap<string, Family> ();
            foreach (unowned string line in text.split ("\n")) {
                var p = line.split ("|");
                if (p.length < 6) continue;
                string name = p[0].strip ();
                if (name == "" || name.has_prefix (".")) continue;
                var fam = map[name];
                if (fam == null) {
                    fam = new Family (name);
                    fam.kind = classify (name, int.parse (p[3]));
                    map[name] = fam;
                }
                string file = p[2];
                if (fam.files.contains (file + "#" + p[1])) continue;
                fam.files.add (file + "#" + p[1]);
                if (file.has_prefix (user_root + "/")) fam.user = true;
                fam.faces.add (new Face (p[1] != "" ? p[1] : "Regular", file, int.parse (p[4]), int.parse (p[5]) != 0));
            }
            foreach (var fam in map.values) {
                fam.sort_faces ();
                c.families.add (fam);
            }
            c.families.sort ((a, b) => a.name.collate (b.name));
            return c;
        }

        public static async Catalog load () {
            string output = "";
            try {
                var proc = new Subprocess.newv ({ "fc-list", "--format", "%{family[0]}|%{style[0]}|%{file}|%{spacing}|%{weight}|%{slant}\\n" },
                    SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE);
                yield proc.communicate_utf8_async (null, null, out output, null);
            } catch (Error e) {
                warning ("fc-list failed: %s", e.message);
            }
            return parse (output ?? "", user_dir ());
        }

        public Gee.List<Family> filter (string category, string query) {
            var list = new Gee.ArrayList<Family> ();
            string q = query.strip ().casefold ();
            foreach (var f in families) {
                if (category == "user" && !f.user) continue;
                if (category == "sans" && f.kind != Kind.SANS) continue;
                if (category == "serif" && f.kind != Kind.SERIF) continue;
                if (category == "mono" && f.kind != Kind.MONO) continue;
                if (category == "display" && f.kind != Kind.DISPLAY) continue;
                if (q != "" && !f.name.casefold ().contains (q)) continue;
                list.add (f);
            }
            return list;
        }

        public static async void refresh_cache () {
            try {
                var proc = new Subprocess.newv ({ "fc-cache", "-f", user_dir () }, SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
                yield proc.wait_async ();
            } catch (Error e) {
                warning ("fc-cache failed: %s", e.message);
            }
        }

        public static async string install (File source) throws Error {
            DirUtils.create_with_parents (user_dir (), 0755);
            var target = File.new_for_path (Path.build_filename (user_dir (), source.get_basename ()));
            if (target.query_exists ()) throw new IOError.EXISTS (_("A font file with this name is already installed"));
            yield source.copy_async (target, FileCopyFlags.NONE, Priority.DEFAULT, null, null);
            yield refresh_cache ();
            return target.get_path ();
        }

        public static async void remove (Family family) throws Error {
            foreach (var face in family.faces) {
                var f = File.new_for_path (face.file);
                if (!face.file.has_prefix (user_dir () + "/")) continue;
                if (f.query_exists ()) yield f.trash_async (Priority.DEFAULT, null);
            }
            yield refresh_cache ();
        }

        public static async string? query_family (string path) {
            try {
                var proc = new Subprocess.newv ({ "fc-query", "--format", "%{family[0]}|%{style[0]}\\n", path },
                    SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE);
                string output;
                yield proc.communicate_utf8_async (null, null, out output, null);
                if (output == null || output.strip () == "") return null;
                return output.split ("\n")[0];
            } catch (Error e) {
                return null;
            }
        }
    }
}
