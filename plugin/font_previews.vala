using GLib;

namespace Singularity.Apps.Fonts {

    public class FontIconProvider : Object, Singularity.FileIconProvider {
        private HashTable<string, Gdk.Texture> cache = new HashTable<string, Gdk.Texture> (str_hash, str_equal);

        public bool matches (GLib.File file, string? content_type) {
            if (file.get_path () == null) return false;
            string name = (file.get_basename () ?? "").down ();
            if (name.has_suffix (".ttf") || name.has_suffix (".otf")) return true;
            if (content_type == null) return false;
            switch (content_type) {
                case "font/ttf":
                case "font/otf":
                case "font/sfnt":
                case "application/x-font-ttf":
                case "application/x-font-otf":
                    return true;
                default:
                    return false;
            }
        }

        public async Gdk.Paintable? load_icon (GLib.File file, int size) {
            string? path = file.get_path ();
            if (path == null) return null;
            int px = size > 0 ? size : 48;
            string key;
            try {
                var info = yield file.query_info_async ("time::modified,standard::size", FileQueryInfoFlags.NONE);
                key = "%s|%llu|%lld|%d".printf (path, info.get_attribute_uint64 ("time::modified"), info.get_size (), px);
            } catch (Error e) {
                return null;
            }
            var cached = cache.lookup (key);
            if (cached != null) return cached;
            var png = Sample.render (null, path, px, px);
            if (png == null) return null;
            try {
                var texture = Gdk.Texture.from_bytes (png);
                cache.insert (key, texture);
                return texture;
            } catch (Error e) {
                return null;
            }
        }
    }

    public class FontPreviewsPlugin : Object, Singularity.FilesPlugin {
        private FontIconProvider? provider = null;
        private Singularity.FilesPluginContext? ctx = null;

        public void activate (Singularity.FilesPluginContext context) {
            ctx = context;
            provider = new FontIconProvider ();
            context.add_file_icon_provider (provider);
        }

        public void deactivate () {
            if (ctx != null && provider != null) ctx.remove_file_icon_provider (provider);
            provider = null;
            ctx = null;
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Singularity.FilesPlugin), typeof (Singularity.Apps.Fonts.FontPreviewsPlugin));
}
