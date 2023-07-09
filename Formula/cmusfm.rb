class Cmusfm < Formula
  desc "Last.fm standalone scrobbler for the cmus music player"
  homepage "https://github.com/Arkq/cmusfm"
  url "https://github.com/Arkq/cmusfm/archive/v0.5.0.tar.gz"
  sha256 "17aae8fc805e79b367053ad170854edceee5f4c51a9880200d193db9862d8363"
  license "GPL-3.0-or-later"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "a5126da2f4356c0ae63e4018e226b1cb692dfccf4d7725558d4bfde4495baebf"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "1072e84a3a3a6a6725497b05a02ac840884b827a0efbb3b23c8a970d5adc9dc9"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "bff70fe49abd28ed98aec28589ca6bba252329c01afe8910235e143013db5fe4"
    sha256 cellar: :any_skip_relocation, ventura:        "52bd3124f7ecae85ff74729a7d2570d3087f92f0490b5379ba55048b8d2a69fe"
    sha256 cellar: :any_skip_relocation, monterey:       "171f836e62399e78fbdf01ed12c42755ed02154a2e05edeeb09bdb97a01df082"
    sha256 cellar: :any_skip_relocation, big_sur:        "0c24879095022d283b1fdf5b8563781cf5c46da121f9d23efade97655fedad9b"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "3c22db499e4c604f11c9b8732a5a7297171c6394c423565bb3fc7eafd1ae98b0"
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "pkg-config" => :build
  depends_on "libfaketime" => :test

  uses_from_macos "curl"

  on_linux do
    depends_on "openssl@3"
  end

  def install
    system "autoreconf", "--install"
    mkdir "build" do
      system "../configure", "--prefix=#{prefix}", "--disable-dependency-tracking", "--disable-silent-rules"
      system "make", "install"
    end
  end

  test do
    cmus_home = testpath/".config/cmus"
    cmusfm_conf = cmus_home/"cmusfm.conf"
    cmusfm_sock = cmus_home/"cmusfm.socket"
    cmusfm_cache = cmus_home/"cmusfm.cache"
    faketime_conf = testpath/".faketimerc"

    test_artist = "Test Artist"
    test_title = "Test Title"
    test_duration = 260
    status_args = %W[
      artist #{test_artist}
      title #{test_title}
      duration #{test_duration}
    ]

    mkpath cmus_home
    touch cmusfm_conf

    begin
      server = fork do
        faketime_conf.write "+0"
        if OS.mac?
          ENV["DYLD_INSERT_LIBRARIES"] = Formula["libfaketime"].lib/"faketime"/"libfaketime.1.dylib"
          ENV["DYLD_FORCE_FLAT_NAMESPACE"] = "1"
        else
          ENV["LD_PRELOAD"] = Formula["libfaketime"].lib/"faketime"/"libfaketime.so.1"
        end
        ENV["FAKETIME_NO_CACHE"] = "1"
        exec bin/"cmusfm", "server"
      end
      loop do
        sleep 0.5
        assert_equal nil, Process.wait(server, Process::WNOHANG)
        break if cmusfm_sock.exist?
      end

      system bin/"cmusfm", "status", "playing", *status_args
      sleep 5
      faketime_conf.atomic_write "+#{test_duration}"
      system bin/"cmusfm", "status", "stopped", *status_args
    ensure
      Process.kill :TERM, server
      Process.wait server
    end

    assert_predicate cmusfm_cache, :exist?
    strings = shell_output "strings #{cmusfm_cache}"
    assert_match(/^#{test_artist}$/, strings)
    assert_match(/^#{test_title}$/, strings)
  end
end
