using Singularity.Apps.Fonts;

void test_parse () {
    string text = "Noto Sans|Regular|/usr/share/fonts/NotoSans-Regular.ttf|0|80|0\n"
        + "Noto Sans|Bold Italic|/usr/share/fonts/NotoSans-BoldItalic.ttf|0|200|100\n"
        + "Noto Sans|Bold|/usr/share/fonts/NotoSans-Bold.ttf|0|200|0\n"
        + "Noto Sans|Regular|/usr/share/fonts/NotoSans-Regular.ttf|0|80|0\n"
        + "DejaVu Sans Mono|Book|/usr/share/fonts/DejaVuSansMono.ttf|100|80|0\n"
        + "Merriweather|Regular|/home/u/.local/share/fonts/Merriweather.ttf|0|80|0\n"
        + "Dancing Script|Regular|/home/u/.local/share/fonts/Dancing.ttf|0|80|0\n"
        + "broken line\n";
    var c = Catalog.parse (text, "/home/u/.local/share/fonts");
    assert (c.families.size == 4);
    var noto = c.filter ("all", "noto")[0];
    assert (noto.faces.size == 3);
    assert (noto.faces[0].style == "Regular" && noto.faces[1].style == "Bold" && noto.faces[2].italic);
    assert (!noto.user && noto.kind == Kind.SANS);
    assert (c.filter ("mono", "")[0].name == "DejaVu Sans Mono");
    assert (c.filter ("serif", "")[0].name == "Merriweather");
    assert (c.filter ("display", "")[0].name == "Dancing Script");
    assert (c.filter ("user", "").size == 2);
    assert (c.filter ("all", "zzz").size == 0);
}

void test_weights () {
    assert (pango_weight (80) == 400 && pango_weight (200) == 700 && pango_weight (0) == 100 && pango_weight (210) == 900);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/fonts/parse", test_parse);
    Test.add_func ("/fonts/weights", test_weights);
    return Test.run ();
}
