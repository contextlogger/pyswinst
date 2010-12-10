# -*- ruby -*-
# sake variant sake4

require 'sake4/component'

def try_load file
  begin
    load file
  rescue LoadError; end
end

$pys60_version = ($sake_op[:pys60] ? $sake_op[:pys60].to_i : 1)

case $pys60_version
when 1
  $uid_v8 = 0x08430009
when 2
  $uid_v8 = 0x0843000b
else
  raise "unsupported PyS60 version"
end

$basename = "pyswinst"

load("version")
$version = PYSWINSTVER.to_s.split(".").map {|x| x.to_i}

$proj = Sake::Project.new(:basename => $basename,
                          :name => "SW Inst API for PyS60v#{$pys60_version}",
                          :version => $version,
                          # This is a test UID.
                          :uid => Sake::Uid.v8($uid_v8),
                          :vendor => "HIIT")

class <<$proj
  def pkg_in_file
    group_dir + ("module.pkg.in")
  end
end

$pyd = Sake::Component.new(:project => $proj,
                           :target_type => :pyd,
                           :basename => $basename,
                           :bin_basename => $basename,
                           :uid3 => Sake::Uid.v8($uid_v8),
                           :caps => Sake::ALL_CAPS)

class <<$pyd
  def mmp_in_file
    group_dir + ("module.mmp.in")
  end
end

$comp_list = [$pyd].compact

if $sake_op[:kits]
  $kits = Sake::DevKits::get_exact_set($sake_op[:kits].strip.split(/,/))
else
  $kits = Sake::DevKits::get_all
end

$kits.delete_if do |kit|
  !kit.supports_python_v?($pys60_version)
end

if $sake_op[:comps]
  comps = $sake_op[:comps].strip.split(/,/)
  $comp_list.delete_if do |comp|
    !comps.include?(comp.basename)
  end
end

$builds = $kits.map do |kit|
  build = Sake::ProjBuild.new(:project => $proj,
                              :devkit => kit)
  if build.v9_up?
    build.handle = (build.handle + ("_py%d" % $pys60_version))
  end
  build.abld_platform = (build.v9_up? ? "gcce" : "armi")
  build.abld_build = ($sake_op[:udeb] ? "udeb" : "urel")
  if $sake_op[:udeb]
    build.handle = (build.handle + "_udeb")
  end
  if $sake_op[:span_5th]
    build.handle = (build.handle + "_5th")
    $span_s60_5th = true
  end
  if build.v9_up?
    build.gcc_version = ($sake_op[:gcce] ? $sake_op[:gcce].to_i : 3)
    if build.gcc_version > 3
      build.handle = (build.handle + ("_gcce%d" % build.gcc_version))
    end
  end
  build
end

# For any v9 builds, configure certificate info for signing.
try_load('local/signing.rb')

$builds.delete_if do |build|
  # Only v9 builds supported, actually.
  # Maybe even not all of them, due to the SWInst API instability.
  !build.v9_up? or (build.sign and !build.cert_file)
end

if $sake_op[:builds]
  blist = $sake_op[:builds]
  $builds.delete_if do |build|
    !blist.include?(build.handle)
  end
end

desc "Prints a list of possible builds."
task :builds do
  for build in $builds
    puts build.handle
  end
end

desc "Prints info about possible builds."
task :build_info do
  for build in $builds
    puts "#{build.handle}:"
    puts "  project name  #{build.project.name}"
    puts "    basename    #{build.project.basename}"
    puts "  target        #{build.target.handle}"
    puts "  devkit        #{build.devkit.handle}"
    puts "  abld platform #{build.abld_platform}"
    puts "  abld build    #{build.abld_build}"
    puts "  sign SIS?     #{build.sign}"
    puts "  cert file     #{build.cert_file}"
    puts "  privkey file  #{build.key_file}"
    puts "  cert caps     #{build.max_caps.inspect}"
    puts "  components    #{build.comp_builds.map {|x| x.component.basename}.inspect}"
  end
end

class HexNum
  def initialize num
    @num = num
  end

  def to_s
    "0x%08x" % @num
  end
end

class Sake::ProjBuild
  def needs_pyd_wrapper?
    # Some problems with imp.load_dynamic, better avoid the issue for
    # now, especially as we are not using the wrapper to include pure
    # Python code yet.
    false # v9_up?
  end
end

class Sake::CompBuild
  def binary_prefix
    return "" if v8_down?
    pfx =
      case $pys60_version
      when 1 then ""
      when 2 then "kf_"
      else raise end
    pfx += "_" if needs_pyd_wrapper?
    pfx
  end

  def binary_suffix
    return "" unless needs_pyd_wrapper?
    "_" + uid3.chex_string
  end

  def binary_file
    generated_file("%s%s%s.%s" % [binary_prefix,
                                  bin_basename,
                                  binary_suffix,
                                  target_ext])
  end

  def pyd_wrapper_basename
    bin_basename
  end

  def pyd_wrapper_file
    generated_file(pyd_wrapper_basename + ".py")
  end

  def pyd_wrapper_path_in_pkg
    # To look for suitable paths, use
    #
    #   import sys
    #   sys.path
    #
    # Yes, it seems putting wrappers on E: is not an option.
    case $pys60_version
    when 1 then "c:\\resource\\"
    when 2 then "c:\\resource\\python25\\"
    else raise end
  end
end

$cbuild_by_pbuild = Hash.new
for pbuild in $builds
  map = pbuild.trait_map

  # To define __UID__ for header files.
  if pbuild.uid
    map[:uid] = HexNum.new(pbuild.uid.number)
  end

  map[:pys60_version] = $pys60_version

  map[($basename + "_version").to_sym] = ($version[0] * 100 + $version[1])

  modname = (pbuild.needs_pyd_wrapper? ? ("_" + $basename) : $basename)
  map[:module_name] = modname
  map[:init_func_name] = ("init" + modname).to_sym

  # NDEBUG controls whether asserts are to be compiled in (NDEBUG is
  # defined in UDEB builds). Normally an assert results in something
  # being printed to the console. To also have the errors logged, you
  # will want to enable logging by setting "logging=true". Without
  # this setting, there will be no dependency on the (deprecated) file
  # logger API, and errors are still displayed on the console (if you
  # have one and have time to read it). "logging=true" has no effect
  # if your SDK does not have the required API.
  if $sake_op[:logging] and map[:has_flogger]
    map[:do_logging] = :define
  end

  # Each build variant shall have all of the components.
  pbuild.comp_builds = $comp_list.map do |comp|
    b = Sake::CompBuild.new(:proj_build => pbuild,
                            :component => comp)
    $cbuild_by_pbuild[pbuild] = b
    b
  end
end

task :default => [:bin, :sis]

require 'sake4/tasks'

Sake::Tasks::def_list_devices_tasks(:builds => $builds)

Sake::Tasks::def_makefile_tasks(:builds => $builds)

Sake::Tasks::def_binary_tasks(:builds => $builds)

Sake::Tasks::def_sis_tasks(:builds => $builds)

Sake::Tasks::def_clean_tasks(:builds => $builds)

task :all => [:makefiles, :bin, :sis]

$doc_build = $builds.last

if $doc_build
  # C++ API documentation.
  Sake::Tasks::def_doxygen_tasks(:build => $doc_build)
  task :all => :cxxdoc
end

# Configure any rules related to releasing and uploading and such
# things. Probably at least involves copying or uploading the
# distribution files somewhere.
try_load('local/releasing.rb')

desc "Prepares web pages."
task :web do
  srcfiles = Dir['web/*.txt2tags.txt']
  sh("darcs changes > web/changelog.txt")
  for srcfile in srcfiles
    htmlfile = srcfile.sub(/\.txt2tags\.txt$/, ".html")
    sh("tools/txt2tags --target xhtml --infile %s --outfile %s --encoding utf-8 --verbose" % [srcfile, htmlfile])
  end
end

dl_dir = $proj.download_dir
dl_path = $proj.to_proj_rel(dl_dir).to_s

desc "Prepares downloads for the current version."
task :release => :web do
  mkdir_p dl_path

  for build in $builds
    ## Unsigned.
    if (not build.sign_sis?) or (build.sign_sis? and ($cert_name == "dev"))
      src_sis_file = build.to_proj_rel(build.long_sis_file).to_s
      sis_basename = File.basename(src_sis_file)
      download_file = File.join(dl_path, sis_basename)
      ln(src_sis_file, download_file, :force => true)
    end

    ## Signed.
    if build.sign_sis? and ($cert_name == "self")
      src_sis_file = build.to_proj_rel(build.long_sisx_file).to_s
      sis_basename = File.basename(src_sis_file)
      download_file = File.join(dl_path, sis_basename)
      ln(src_sis_file, download_file, :force => true)
    end
  end
end

Sake::Tasks::force_uncurrent_on_op_change

def sis_info opt
  for build in $builds
    if build.short_sisx_file.exist?
      sh("sisinfo -f #{build.short_sisx_file} #{opt}")
    end
  end
end

task :sis_ls do
  sis_info "-i"
end

task :sis_cert do
  sis_info "-c"
end

task :sis_struct do
  sis_info "-s"
end
