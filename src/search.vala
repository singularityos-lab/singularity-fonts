namespace Singularity.Apps.Fonts {

    public class FontsSearch : Singularity.SearchProviderService {
        private const int MAX_RESULTS = 12;
        private weak FontsApp app;
        private Catalog? catalog = null;
        private int64 loaded_at = 0;

        public FontsSearch (FontsApp app) {
            this.app = app;
        }

        private async Catalog current () {
            int64 now = get_monotonic_time ();
            if (catalog == null || now - loaded_at > 30 * TimeSpan.SECOND) {
                catalog = yield Catalog.load ();
                loaded_at = now;
            }
            return catalog;
        }

        private Family? find (string name) {
            if (catalog == null) return null;
            foreach (var fam in catalog.families) {
                if (fam.name == name) return fam;
            }
            return null;
        }

        public override async string[] get_initial_results (string[] terms, Cancellable? cancellable) throws Error {
            string query = string.joinv (" ", terms).strip ().casefold ();
            string[] ids = {};
            if (query.char_count () < 2) return ids;
            var cat = yield current ();
            var starts = new Gee.ArrayList<string> ();
            var contains = new Gee.ArrayList<string> ();
            foreach (var fam in cat.families) {
                string name = fam.name.casefold ();
                if (name.has_prefix (query)) starts.add (fam.name);
                else if (name.contains (query)) contains.add (fam.name);
            }
            starts.add_all (contains);
            foreach (string name in starts) {
                if (ids.length >= MAX_RESULTS) break;
                ids += name;
            }
            return ids;
        }

        public override async Singularity.SearchResultMeta[] get_result_metas (string[] ids, Cancellable? cancellable) throws Error {
            yield current ();
            Singularity.SearchResultMeta[] metas = {};
            foreach (string id in ids) {
                var fam = find (id);
                if (fam == null) continue;
                var meta = new Singularity.SearchResultMeta (id, fam.name);
                meta.description = "%s · %s".printf (fam.kind.label (), fam.styles_label ());
                var png = Sample.render (fam.name, null);
                if (png != null) meta.preview_icon = new BytesIcon (png);
                meta.add_action ("copy", _("Copy Font Name"), "edit-copy-symbolic");
                metas += meta;
            }
            return metas;
        }

        public override async Singularity.SearchActivationReply? activate_result (string id, string[] terms, uint32 timestamp) throws Error {
            app.show_family (id);
            return null;
        }

        public override async Singularity.SearchActivationReply? activate_action (string id, string action_id, string[] terms, uint32 timestamp) throws Error {
            return Singularity.SearchActivationReply.copy (id);
        }
    }
}
