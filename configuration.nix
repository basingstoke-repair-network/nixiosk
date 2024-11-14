{ lib, pkgs, config, ...}: {

  imports = [
    ./custom.nix
    ./hardware/raspberrypi.nix
    ./hardware/ova.nix
    ./hardware/qemu.nix
    ./hardware/all.nix # used for iso and pxe
  ];

  hardware.opengl.enable = true;
  hardware.bluetooth.enable = true;
  hardware.pulseaudio.enable = true;
  services.dbus.enable = true;

  # theming
  gtk.iconCache.enable = true;
  environment.systemPackages = [
    pkgs.adwaita-icon-theme
    pkgs.hicolor-icon-theme

    (pkgs.git.override {
      withManual = false;
      pythonSupport = false;
      withpcre2 = false;
      perlSupport = false;
    })
  ];

  # input
  services.udev.packages = [ pkgs.libinput.out ];

  nix = {
    settings = {
      substituters = ["https://nixiosk.cachix.org"];
      trusted-public-keys = ["nixiosk.cachix.org-1:A4kH9p+y9NjDWj0rhaOnv3OLIOPTbjRIsXRPEeTtiS4="];
    };
  };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "without-password";
    startWhenNeeded = true;
  };

  users.users.kiosk = {
    isNormalUser = true;
    useDefaultShell = true;
  };

  systemd.services."cage@" = {
    serviceConfig.Restart = "always";
    environment = {
      WLR_LIBINPUT_NO_DEVICES = "1";
      NO_AT_BRIDGE = "1";
      COG_URL = "https://duckduckgo.com"; # used if no url is specified
    } // lib.optionalAttrs (config.environment.variables ? GDK_PIXBUF_MODULE_FILE) {
      GDK_PIXBUF_MODULE_FILE = config.environment.variables.GDK_PIXBUF_MODULE_FILE;
    };
  };

  systemd.enableEmergencyMode = false;
  systemd.services."serial-getty@ttyS0".enable = false;
  systemd.services."serial-getty@hvc0".enable = false;
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;

  services.udisks2.enable = false;
  documentation.enable = false;
  powerManagement.enable = false;
  programs.command-not-found.enable = false;

  services.cage = {
    enable = true;
    user = "kiosk";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true;
      addresses = true;
      hinfo = true;
      workstation = true;
      domain = true;
    };
  };
  environment.etc."avahi/services/ssh.service" = {
    text = ''
      <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_ssh._tcp</type>
          <port>22</port>
        </service>
      </service-group>
    '';
  };

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [

    # Disable some things that don’t cross compile
    (self: super: lib.optionalAttrs (super.stdenv.hostPlatform != super.stdenv.buildPlatform) {
      gtk3 = super.gtk3.override { cupsSupport = false; };
      webkitgtk = super.webkitgtk.override {
        enableGeoLocation = false;
        stdenv = super.stdenv;
      };

      kodi = super.kodi.override {
        sambaSupport = false;
        rtmpSupport = false;
        joystickSupport = false;
      };
    }) (self: super: {
      grub2 = super.grub2.override { zfsSupport = false; };

      retroarchBare = (super.retroarchBare.override {
        withVulkan = false;
        withX11 = false;
      }).overrideAttrs (o: {
        patches = (o.patches or []) ++ [ ./retroarch-lakkaish.patch ];
      });

      # armv6l (no NEON) and aarch64 don’t have prebuilt cores, so
      # provide some here that are known to work well. Feel free to
      # include more that are known to work here. To add more cores,
      # or update existing core, contribute them upstream in Nixpkgs
      retroarch = if (builtins.elem super.stdenv.hostPlatform.parsed.cpu.name ["armv6l" "aarch64"]) then (super.retroarch.override {
        cores = {
          armv6l = with super.libretro; [ snes9x stella fbalpha2012 fceumm vba-next vecx handy prboom bluemsx ];
          aarch64 = with super.libretro; [ atari800 beetle-gba beetle-lynx beetle-ngp beetle-pce-fast beetle-pcfx beetle-psx beetle-psx-hw beetle-saturn beetle-saturn-hw beetle-snes beetle-supergrafx beetle-vb beetle-wswan bluemsx bsnes-mercury citra desmume desmume2015 dosbox eightyone fbalpha2012 fbneo fceumm fmsx freeintv gambatte genesis-plus-gx gpsp gw handy hatari mame2000 mame2003 mame2003-plus mesen meteor mgba mupen64plus neocd nestopia o2em opera parallel-n64 pcsx_rearmed ppsspp prboom prosystem quicknes sameboy smsplus-gx snes9x snes9x2002 snes9x2005 snes9x2010 stella stella2014 tgbdual vba-m vba-next vecx virtualjaguar yabause picodrive ];
        }.${super.stdenv.hostPlatform.parsed.cpu.name} or [];
      }).overrideAttrs (o: {
        patches = (o.patches or []) ++ [ ./retroarch-lakkaish.patch ];
      }) else self.retroarchBare;

      kodi = super.kodi.override {
        waylandSupport = true;
        x11Support = false;
      };

      cog = super.cog.overrideAttrs (o: {
        cmakeFlags = (o.cmakeFlags or []) ++ ["-DCOG_DBUS_SYSTEM_BUS=ON" "-DCOG_DBUS_OWN_USER=kiosk"];
      });

      libinput = super.libinput.override (o: {
        documentationSupport = false;
      });
    }) ];

    # We use remote builders for things like 32-bit arm where there is
    # no binary cache, otherwise, we might as well build it natively,
    # with the cache covering most of it.
    localSystem = let
      cachedSystems = [ "aarch64-linux" "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in if builtins.elem (config.nixpkgs.crossSystem.system or null) cachedSystems
       then config.nixpkgs.crossSystem
       else if (config.nixiosk.localSystem.hostName != null) && (config.nixiosk.localSystem.sshUser != null) && (config.nixiosk.localSystem.system != null) then { inherit (config.nixiosk.localSystem) system; }
       else (lib.mkIf (config.nixpkgs.crossSystem.system or null != null) config.nixpkgs.crossSystem);
  };

  boot.plymouth.enable = false;
  boot.kernelParams = [ "rd.udev.log_priority=3" "vt.global_cursor_default=0" ];

  networking.dhcpcd.extraConfig = ''
    timeout 0
    noarp
  '';

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.login1.power-off" ||
	        action.id == "org.freedesktop.login1.reboot") {
        return polkit.Result.YES;
      }
    });
  '';

}
