namespace Singularity.Apps.Fonts {

    [CCode (cname = "pango_font_map_add_font_file", cheader_filename = "pango/pango.h")]
    public extern bool font_map_add_font_file (Pango.FontMap map, string filename) throws GLib.Error;

    namespace Sample {
        [CCode (cname = "FcConfigCreate", cheader_filename = "fontconfig/fontconfig.h")]
        private extern void* fc_config_create ();
        [CCode (cname = "FcConfigAppFontAddFile", cheader_filename = "fontconfig/fontconfig.h")]
        private extern bool fc_config_app_font_add_file (void* config, string file);
        [CCode (cname = "FcConfigDestroy", cheader_filename = "fontconfig/fontconfig.h")]
        private extern void fc_config_destroy (void* config);
        [CCode (cname = "pango_fc_font_map_set_config", cheader_filename = "pango/pangofc-fontmap.h")]
        private extern void fc_font_map_set_config (Pango.FontMap map, void* config);

        public Bytes? render (string? family, string? file, int width = 112, int height = 80) {
            var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
            var cr = new Cairo.Context (surface);
            double r = height * 0.18;
            cr.new_sub_path ();
            cr.arc (width - r, r, r, -Math.PI / 2, 0);
            cr.arc (width - r, height - r, r, 0, Math.PI / 2);
            cr.arc (r, height - r, r, Math.PI / 2, Math.PI);
            cr.arc (r, r, r, Math.PI, 3 * Math.PI / 2);
            cr.close_path ();
            cr.set_source_rgb (0.965, 0.961, 0.957);
            cr.fill ();
            Pango.Layout layout;
            if (file != null) {
                var config = fc_config_create ();
                if (!fc_config_app_font_add_file (config, file)) {
                    fc_config_destroy (config);
                    return null;
                }
                var map = Pango.CairoFontMap.new ();
                fc_font_map_set_config (map, config);
                fc_config_destroy (config);
                var ctx = map.create_context ();
                Pango.cairo_update_context (cr, ctx);
                layout = new Pango.Layout (ctx);
            } else {
                layout = Pango.cairo_create_layout (cr);
            }
            var desc = new Pango.FontDescription ();
            desc.set_family (family ?? "sans");
            desc.set_absolute_size (height * 0.55 * Pango.SCALE);
            layout.set_font_description (desc);
            layout.set_text ("Aa", -1);
            int lw, lh;
            layout.get_pixel_size (out lw, out lh);
            cr.set_source_rgb (0.17, 0.17, 0.17);
            cr.move_to ((width - lw) / 2.0, (height - lh) / 2.0);
            Pango.cairo_show_layout (cr, layout);
            surface.flush ();
            var buffer = new ByteArray ();
            var status = surface.write_to_png_stream ((data) => {
                buffer.append (data);
                return Cairo.Status.SUCCESS;
            });
            if (status != Cairo.Status.SUCCESS) return null;
            return ByteArray.free_to_bytes ((owned) buffer);
        }
    }
}
