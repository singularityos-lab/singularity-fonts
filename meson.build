project('singularity-fonts', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0'
)

i18n = import('i18n')
add_project_arguments('-DGETTEXT_PACKAGE="singularity-fonts"', language: 'c')
subdir('po')

gnome = import('gnome')

gtk_dep   = dependency('gtk4')
gee_dep   = dependency('gee-0.8')
pango_dep = dependency('pango', version: '>= 1.56')
pangocairo_dep = dependency('pangocairo')
pangoft2_dep = meson.get_compiler('c').find_library('pangoft2-1.0')
fontconfig_dep = meson.get_compiler('c').find_library('fontconfig')
math_dep = meson.get_compiler('c').find_library('m')

libsingularity_dep = dependency('singularity-1.0',
  fallback: ['libsingularity', 'libsingularity_dep']
)

if not meson.is_subproject() and libsingularity_dep.type_name() == 'internal'
  libsingularity_vapi_dir = join_paths(meson.project_build_root(), 'subprojects', 'libsingularity')
  add_project_arguments(['--vapidir=' + libsingularity_vapi_dir], language: 'vala')
endif

resources = gnome.compile_resources(
  'singularity-fonts-resources',
  'resources/dev.sinty.fonts.gresource.xml',
  source_dir: meson.current_source_dir() / 'data' / 'icons',
)

executable('singularity-fonts',
  files('src/model.vala', 'src/sample.vala', 'src/search.vala', 'src/window.vala', 'src/agent_intents.vala', 'src/app.vala') + [resources],
  dependencies: [gtk_dep, gee_dep, pango_dep, pangocairo_dep, pangoft2_dep, fontconfig_dep, math_dep, libsingularity_dep],
  install: true
)

model_test = executable('fonts-test',
  files('src/model.vala', 'tests/model_test.vala'),
  dependencies: [gee_dep, pango_dep, dependency('gio-2.0')],
)
test('fonts', model_test)

install_data('data/dev.sinty.fonts.desktop',
  install_dir: get_option('datadir') / 'applications'
)

shared_module('font-previews',
  files('src/sample.vala', 'plugin/font_previews.vala'),
  dependencies: [gtk_dep, pango_dep, pangocairo_dep, pangoft2_dep, fontconfig_dep, math_dep, libsingularity_dep, dependency('libpeas-2')],
  install: true,
  install_dir: get_option('libdir') / 'singularity' / 'plugins' / 'font-previews'
)

install_data('plugin/font-previews.plugin',
  install_dir: get_option('libdir') / 'singularity' / 'plugins' / 'font-previews'
)

install_data('data/dev.sinty.fonts.install.ini',
  install_dir: get_option('datadir') / 'singularity' / 'files-actions'
)

install_data('data/dev.sinty.fonts.search-provider.ini',
  rename: 'dev.sinty.fonts.ini',
  install_dir: get_option('datadir') / 'singularity' / 'search-providers'
)

service_conf = configuration_data()
service_conf.set('bindir', get_option('prefix') / get_option('bindir'))
configure_file(
  input: 'data/dev.sinty.fonts.service.in',
  output: 'dev.sinty.fonts.service',
  configuration: service_conf,
  install_dir: get_option('datadir') / 'dbus-1' / 'services'
)

install_data('data/dev.sinty.fonts.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

install_data('data/icons/dev.sinty.fonts.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
)

iride = find_program('iride', required: get_option('iride'))
if iride.found()
  custom_target('iride-icon',
    input: 'data/icons/iride/iride.json',
    output: 'dev.sinty.fonts.iride',
    depend_files: files(
      'data/icons/iride/layers/000.svg',
      'data/icons/iride/layers/001.svg',
      'data/icons/iride/layers/002.svg',
      'data/icons/iride/layers/003.svg',
      'data/icons/iride/layers/004.svg',
      'data/icons/iride/layers/005.svg',
      'data/icons/iride/layers/006.svg',
      'data/icons/iride/layers/007.svg',
      'data/icons/iride/layers/008.svg',
      'data/icons/iride/layers/009.svg',
      'data/icons/iride/layers/grande-0.svg',
      'data/icons/iride/layers/grande-1.svg',
      'data/icons/iride/layers/grande-2.svg',
      'data/icons/iride/layers/grande-dietro-0.svg',
      'data/icons/iride/layers/grande-dietro-1.svg',
      'data/icons/iride/layers/grande-dietro-2.svg',
      'data/icons/iride/layers/piccola-0.svg',
      'data/icons/iride/layers/piccola-1.svg',
      'data/icons/iride/layers/piccola-dietro-0.svg',
      'data/icons/iride/layers/piccola-dietro-1.svg',
    ),
    command: [iride, 'build', meson.current_source_dir() / 'data' / 'icons' / 'iride', '@OUTPUT@'],
    install: true,
    install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
  )
endif
