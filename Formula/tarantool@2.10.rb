class TarantoolAT210 < Formula
  desc "In-memory database and Lua application server"
  homepage "https://tarantool.org/"
  url "https://download.tarantool.org/tarantool/src/tarantool-2.10.2.tar.gz"
  sha256 "2873992c88a7f549d953d9bc155e102300a78af24eb928fb40b642b2d1aca0ae"
  license "BSD-2-Clause"

  bottle do
    root_url "https://github.com/tarantool/homebrew-tap/releases/download/tarantool@2.10-2.10.1"
    sha256                               big_sur:      "fbf8261734cba2da450dc5191269560f0dcab89f0f6aaf4649adededbb4c2b5c"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "7fdedf52f05ab822d3554c1b7ae0a2e88d3d17c80eada6edb8035499cdf62ddc"
  end

  head do
    url "https://github.com/tarantool/tarantool.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "cmake" => :build
  depends_on "icu4c"
  depends_on "openssl@1.1"
  depends_on "readline"

  uses_from_macos "curl"
  uses_from_macos "ncurses"

  def install
    later_than_bigsur = MacOS.version >= :big_sur
    sdk = later_than_bigsur ? MacOS.sdk_path_if_needed : ""
    lib_suffix = later_than_bigsur ? "tbd" : "dylib"

    # Necessary for luajit to build on macOS Mojave (see luajit formula)
    ENV["MACOSX_DEPLOYMENT_TARGET"] = MacOS.version

    # Avoid keeping references to Homebrew's clang/clang++ shims
    inreplace "src/trivia/config.h.cmake",
              "#define COMPILER_INFO \"@CMAKE_C_COMPILER@ @CMAKE_CXX_COMPILER@\"",
              "#define COMPILER_INFO \"/usr/bin/clang /usr/bin/clang++\""

    args = std_cmake_args + %W[
      -DCMAKE_BUILD_TYPE=RelWithDebInfo
      -DCMAKE_INSTALL_MANDIR=#{doc}
      -DCMAKE_INSTALL_SYSCONFDIR=#{etc}
      -DCMAKE_INSTALL_LOCALSTATEDIR=#{var}
      -DENABLE_DIST=ON
      -DOPENSSL_ROOT_DIR=#{Formula["openssl@1.1"].opt_prefix}
      -DREADLINE_ROOT=#{Formula["readline"].opt_prefix}
      -DENABLE_BUNDLED_LIBCURL=OFF
      -DICONV_INCLUDE_DIR=#{sdk}/usr/include
    ]
    args += if OS.mac?
      %W[
        -DCURL_INCLUDE_DIR={sdk}/usr/include
        -DCURL_LIBRARY=#{sdk}/usr/lib/libcurl.#{lib_suffix}
        -DCURSES_NEED_NCURSES=TRUE
        -DCURSES_NCURSES_INCLUDE_PATH=#{sdk}/usr/include
        -DCURSES_NCURSES_LIBRARY=#{sdk}/usr/lib/libncurses.#{lib_suffix}
      ]
    else
      %W[
        -DCURL_ROOT=#{Formula["curl"].opt_prefix}
      ]
    end
    # In brief: when "src/lib/small" is in include paths,
    # `#include <version>` from inside of Mac OS SDK headers
    # attempts to include "src/lib/small/VERSION" as a
    # header file that leads to a syntax error.
    rm_f "src/lib/small/VERSION"

    mkdir "build" do
      system "cmake", "..", *args
      system "make", "install"
    end
  end

  def post_install
    local_user = ENV["USER"]
    inreplace etc/"default/tarantool", /(username\s*=).*/, "\\1 '#{local_user}'"

    (var/"lib/tarantool").mkpath
    (var/"log/tarantool").mkpath
    (var/"run/tarantool").mkpath
  end

  test do
    (testpath/"test.lua").write <<~EOS
      box.cfg{}
      local s = box.schema.create_space("test")
      s:create_index("primary")
      local tup = {1, 2, 3, 4}
      s:insert(tup)
      local ret = s:get(tup[1])
      if (ret[3] ~= tup[3]) then
        os.exit(-1)
      end
      os.exit(0)
    EOS
    system bin/"tarantool", "#{testpath}/test.lua"
  end
end
