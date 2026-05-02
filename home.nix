{ config, pkgs, lib, isDesktop, nixgl, ... }:

{
  home.username = "eggplants";
  home.homeDirectory = "/home/eggplants";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ── nixGL (OpenGL wrapper for non-NixOS) ──────────────────────────────────
  # Required for GPU-accelerated apps (e.g. Ghostty) installed via Nix on Ubuntu.

  targets.genericLinux.nixGL.packages = nixgl.packages.x86_64-linux;
  targets.genericLinux.nixGL.defaultWrapper = "mesa";

  # ── Packages ──────────────────────────────────────────────────────────────

  home.packages = with pkgs; [
    curl wget w3m jq unar
    ffmpeg imagemagick
    timidity pkg-config
    jdk21 maven
    pass yt-dlp
    python314Packages.getjump
    # Docker (rootless; daemon runs as systemd.user.services.docker)
    docker docker-buildx docker-compose
    rootlesskit slirp4netns fuse-overlayfs
  ] ++ lib.optionals isDesktop [
    feh vlc rhythmbox alsa-utils
    # GPU-accelerated apps wrapped with nixGL for Ubuntu
    (config.lib.nixGL.wrap pkgs.ghostty)
    (config.lib.nixGL.wrap pkgs.google-chrome)
    pkgs.gnomeExtensions.runcat
    pkgs.hackgen-nf-font
  ];

  # ── Git ───────────────────────────────────────────────────────────────────

  programs.git.enable = true;

  # ── Docker (rootless) ─────────────────────────────────────────────────────

  systemd.user.services.docker = {
    Unit = {
      Description = "Docker Application Container Engine (Rootless)";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${pkgs.docker}/bin/dockerd-rootless";
      ExecReload = "${pkgs.util-linux}/bin/kill -s HUP $MAINPID";
      Restart = "always";
      RestartSec = 2;
      Delegate = "yes";
      Type = "notify";
      NotifyAccess = "all";
      KillMode = "mixed";
      LimitNOFILE = "infinity";
      LimitNPROC = "infinity";
      LimitCORE = "infinity";
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock";

  # Expose Nix profile to the GNOME (systemd user) session.
  # systemd reads ~/.config/environment.d/ — not /etc/profile.d/nix.sh —
  # so without this, the GNOME session has no ~/.nix-profile/{bin,share}.
  home.sessionVariables.XDG_DATA_DIRS = "/home/${config.home.username}/.nix-profile/share:/nix/var/nix/profiles/default/share:/usr/local/share:/usr/share:/var/lib/snapd/desktop";
  home.sessionVariables.PATH = "/home/${config.home.username}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:\${PATH}";
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  # Write all git config to ~/.gitconfig via activation (idempotent).
  home.activation.gitConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _git="${pkgs.git}/bin/git"

    # credential.helper: unset-all first to prevent duplicates on re-runs
    $_git config --global --unset-all credential.helper || true
    $_git config --global credential.helper ""
    $_git config --global --add credential.helper "!/usr/bin/env gh auth git-credential"

    $_git config --global commit.gpgSign  true
    $_git config --global tag.gpgSign     true
    $_git config --global core.editor     nano
    $_git config --global gpg.program     "${pkgs.gnupg}/bin/gpg"
    $_git config --global help.autocorrect 1
    $_git config --global pull.rebase     false
    $_git config --global push.autoSetupRemote true
    $_git config --global rebase.autosquash    true
    $_git config --global user.name       "eggplants"

    # Codeberg: SSH push rewrite — remove section first for idempotency
    $_git config --global --remove-section 'url.git@codeberg.org:' || true
    $_git config --global 'url.git@codeberg.org:.pushInsteadOf' 'git://codeberg.org/'
    $_git config --global --add 'url.git@codeberg.org:.pushInsteadOf' 'https://codeberg.org/'
  '';

  # Derive email and signing key from GPG keyring — runs after gitConfig
  home.activation.gitFromGpg = lib.hm.dag.entryAfter ["writeBoundary" "gitConfig"] ''
    if ${pkgs.gnupg}/bin/gpg --list-secret-keys &>/dev/null 2>&1; then
      _key=$(${pkgs.gnupg}/bin/gpg --list-secret-keys \
        | ${pkgs.coreutils}/bin/tac \
        | ${pkgs.gnugrep}/bin/grep -m1 -B1 '^sec' \
        | ${pkgs.coreutils}/bin/head -1 \
        | ${pkgs.gawk}/bin/awk '$0=$1')
      _email=$(${pkgs.gnupg}/bin/gpg --list-keys \
        | ${pkgs.gnugrep}/bin/grep -Em1 '^uid' \
        | ${pkgs.util-linux}/bin/rev \
        | ${pkgs.coreutils}/bin/cut -f1 -d' ' \
        | ${pkgs.coreutils}/bin/tr -d '<>' \
        | ${pkgs.util-linux}/bin/rev)
      [[ -n "$_key"   ]] && ${pkgs.git}/bin/git config --global user.signingkey "$_key"
      [[ -n "$_email" ]] && ${pkgs.git}/bin/git config --global user.email      "$_email"
    fi
  '';

  # ── GPG agent ─────────────────────────────────────────────────────────────

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 34560000;
    maxCacheTtl = 34560000;
    enableSshSupport = true;
    pinentry.package =
      if isDesktop then pkgs.pinentry-gnome3 else pkgs.pinentry-tty;
  };

  # ── Mise (runtime manager) ────────────────────────────────────────────────

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig = {
      tools = {
        python = "latest";
        ruby = "latest";
        node = "latest";
        go = "latest";
        rust = "latest";
        gh = "latest";
      };
      settings = {
        # Avoid compiling Ruby from source
        ruby.compile = false;
      };
    };
  };

  # ── Zsh ───────────────────────────────────────────────────────────────────

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;
    enableCompletion = true;

    history = {
      size = 100000;
      save = 100000;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      share = true;
      extended = true;
      append = true;
    };

    shellAliases = {
      ll       = "ls -lGF --color=auto";
      ls       = "ls -GF --color=auto";
      wine-rpg = ''FONTCONFIG_FILE="$HOME/.config/wine/font-noaa.conf" wine'';
      hms      = "home-manager switch --flake ~/.config/home-manager#eggplants-desktop";
    };

    completionInit = ''
      autoload -U compinit && compinit
      zstyle ':completion:*' menu select
      zstyle ':completion:*:default' list-colors "''${(s.:.)LS_COLORS}"
    '';

    initContent = ''
      setopt correct autocd nolistbeep aliasfuncdef
      setopt extendedglob interactivecomments prompt_subst
      unsetopt nomatch

      bindkey '^[[A' up-line-or-search
      bindkey '^[[B' down-line-or-search

      [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

      case "$TERM" in
        xterm-color | *-256color) color_prompt=yes ;;
      esac

      export LSCOLORS=gxfxcxdxbxegedabagacag
      export LS_COLORS='di=36;40:ln=35;40:so=32;40:pi=33;40:ex=31;40:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;46'

      export JAVA_HOME="/usr/lib/jvm/default-java"
      export CLASSPATH=".:$JAVA_HOME/jre/lib:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar"
      export PATH="$PATH:$JAVA_HOME/bin"
      export M2_HOME="/opt/maven"
      export MAVEN_HOME="/opt/maven"
      export PATH="$PATH:$M2_HOME/bin"
      export PATH="$HOME/.local/bin:$PATH"

      # GPG SSH agent
      unset SSH_AGENT_PID
      if [ "''${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
        export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
      fi
      export GPG_TTY=$(tty)
      gpg-connect-agent updatestartuptty /bye >/dev/null

      # pure prompt (installed via nixpkgs)
      fpath+=("${pkgs.pure-prompt}/share/zsh/site-functions")
      autoload -U promptinit && promptinit && prompt pure
    '';

    # wine() wrapper lives in .zshenv so it applies before .zshrc
    envExtra = ''
      function wine() {
        locale -a | grep -qF ja_JP || sudo apt install language-pack-ja -y
        LANG=ja_JP.utf8 /usr/bin/env wine "$@"
      }
    '';
  };

  # ── Nano ──────────────────────────────────────────────────────────────────

  home.file.".nanorc".text = ''
    include "~/.nano/*.nanorc"

    set autoindent
    set constantshow
    set linenumbers
    set tabsize 4
    set softwrap

    set titlecolor white,red
    set numbercolor white,blue
    set selectedcolor white,green
    set statuscolor white,green
  '';

  # Clone syntax highlight themes on first activation
  home.activation.nanoHighlight = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! [[ -d $HOME/.nano ]]; then
      ${pkgs.git}/bin/git clone --depth 1 --single-branch \
        'https://github.com/serialhex/nano-highlight' \
        "$HOME/.nano"
    fi
  '';

  # ── Wine setup (desktop only) ────────────────────────────────────────────

  # Start timidity as ALSA MIDI sequencer on login (required for Wine audio)
  systemd.user.services.timidity = lib.mkIf isDesktop {
    Unit.Description = "TiMidity++ ALSA MIDI sequencer";
    Service = {
      ExecStart = "${pkgs.timidity}/bin/timidity -iAD";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # ── Fonts ─────────────────────────────────────────────────────────────────

  fonts.fontconfig.enable = lib.mkIf isDesktop true;

  # ── GNOME extensions (desktop only) ──────────────────────────────────────
  # On non-NixOS, GNOME Shell only scans ~/.local/share/gnome-shell/extensions/.
  # Symlink Nix-installed extensions into that directory so they are discoverable.

  xdg.dataFile = lib.mkIf isDesktop {
    "gnome-shell/extensions/runcat@kolesnikov.se".source =
      "${pkgs.gnomeExtensions.runcat}/share/gnome-shell/extensions/runcat@kolesnikov.se";
  };

  # ── GNOME desktop entries (desktop only) ──────────────────────────────────
  # The .desktop files bundled with nixGL-wrapped packages still point to the
  # raw Nix store path (unwrapped). Override them so the Launcher invokes the
  # nixGL wrappers in ~/.nix-profile/bin instead.

  xdg.desktopEntries = lib.mkIf isDesktop {
    google-chrome = {
      name = "Google Chrome";
      exec = "google-chrome %U";
      icon = "google-chrome";
      categories = [ "Network" "WebBrowser" ];
      mimeType = [
        "text/html" "text/xml" "application/xhtml+xml"
        "x-scheme-handler/http" "x-scheme-handler/https"
        "x-scheme-handler/ftp"
      ];
    };
    "com.mitchellh.ghostty" = {
      name = "Ghostty";
      exec = "ghostty --gtk-single-instance=true";
      icon = "com.mitchellh.ghostty";
      categories = [ "System" "TerminalEmulator" ];
    };
  };

  # ── Default applications (desktop only) ──────────────────────────────────

  xdg.mimeApps = lib.mkIf isDesktop {
    enable = true;
    defaultApplications = {
      "text/html"                = "google-chrome.desktop";
      "application/xhtml+xml"    = "google-chrome.desktop";
      "text/xml"                 = "google-chrome.desktop";
      "x-scheme-handler/http"    = "google-chrome.desktop";
      "x-scheme-handler/https"   = "google-chrome.desktop";
      "x-scheme-handler/ftp"     = "google-chrome.desktop";
    };
  };

  # ── GNOME settings (desktop only) ────────────────────────────────────────

  dconf.settings = lib.mkIf isDesktop {
    "org/gnome/desktop/default-applications/terminal" = {
      exec = "ghostty";
      exec-arg = "";
    };
    "org/gnome/shell" = {
      enabled-extensions = [ "runcat@kolesnikov.se" ];
    };
    "org/gnome/shell/extensions/dash-to-dock" = {
      extend-height = false;
      dock-position = "BOTTOM";
      dash-max-icon-size = 16;
      intellihide = false;
      dock-fixed = false;
    };
    "org/gnome/desktop/interface" = {
      text-scaling-factor = 1.0;
    };
  };

  # ── VSCode (desktop only) ─────────────────────────────────────────────────

  programs.vscode = lib.mkIf isDesktop {
    enable = true;
    package = config.lib.nixGL.wrap pkgs.vscode;
    # ms-vscode-remote.remote-containers is not in nixpkgs; install manually after switch:
    #   code --install-extension ms-vscode-remote.remote-containers
  };

  # ── Ghostty config (desktop only) ────────────────────────────────────────

  xdg.configFile."ghostty/config.ghostty" = lib.mkIf isDesktop {
    text = ''
      term = xterm-ghostty

      theme = Andromeda

      font-family = HackGen Console NF
      font-size = 11

      font-thicken = true
      font-thicken-strength = 1

      font-style-bold = false
      font-style-italic = false
      font-style-bold-italic = false

      adjust-cell-width = -1
      adjust-cell-height = 2

      cursor-style = block
      cursor-style-blink = false
      cursor-invert-fg-bg = true
      cursor-opacity = 0.8

      mouse-hide-while-typing = true
      resize-overlay = never

      keybind = ctrl+shift+f=start_search

      keybind = ctrl+f2=new_split:right
      keybind = f2+shift=new_split:down

      keybind = shift+arrow_up=goto_split:up
      keybind = shift+arrow_down=goto_split:down
      keybind = shift+arrow_left=goto_split:left
      keybind = shift+arrow_right=goto_split:right

      keybind = alt+shift+arrow_up=resize_split:up,10
      keybind = alt+shift+arrow_down=resize_split:down,10
      keybind = alt+shift+arrow_left=resize_split:left,10
      keybind = alt+shift+arrow_right=resize_split:right,10

      keybind = f2=new_tab

      keybind = f3=previous_tab
      keybind = f4=next_tab

      keybind = alt+digit_1=goto_tab:1
      keybind = alt+1=goto_tab:1
      keybind = alt+digit_2=goto_tab:2
      keybind = alt+2=goto_tab:2
      keybind = alt+digit_3=goto_tab:3
      keybind = alt+3=goto_tab:3
      keybind = alt+digit_4=goto_tab:4
      keybind = alt+4=goto_tab:4
      keybind = alt+digit_5=goto_tab:5
      keybind = alt+5=goto_tab:5
      keybind = alt+digit_6=goto_tab:6
      keybind = alt+6=goto_tab:6
      keybind = alt+digit_7=goto_tab:7
      keybind = alt+7=goto_tab:7
      keybind = alt+digit_8=goto_tab:8
      keybind = alt+8=goto_tab:8
      keybind = alt+9=last_tab
    '';
  };

  # ── Wine font config (desktop only) ───────────────────────────────────────

  xdg.configFile."wine/font-noaa.conf" = lib.mkIf isDesktop {
    text = ''
      <?xml version='1.0'?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
       <include>/etc/fonts/fonts.conf</include>
       <match target="font">
        <edit mode="assign" name="rgba">
         <const>none</const>
        </edit>
       </match>
      </fontconfig>
    '';
  };
}
