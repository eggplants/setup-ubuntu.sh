{ config, pkgs, lib, isDesktop, nixgl, ... }:

{
  home.username = "eggplants";
  home.homeDirectory = "/home/eggplants";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ── nixGL (OpenGL wrapper for non-NixOS) ──────────────────────────────────
  # Required for GPU-accelerated apps (e.g. Ghostty) installed via Nix on Ubuntu.

  nixGL.packages = nixgl.packages.x86_64-linux;
  nixGL.defaultWrapper = "mesa";

  # ── Packages ──────────────────────────────────────────────────────────────

  home.packages = with pkgs; [
    curl wget w3m jq unar
    ffmpeg imagemagick
    timidity pkg-config
    jdk21 maven
    pass yt-dlp
    pinentry-tty
    python314Packages.getjump
    # Docker (rootless; daemon runs as systemd.user.services.docker)
    docker docker-buildx docker-compose
    rootlesskit slirp4netns fuse-overlayfs
  ] ++ lib.optionals isDesktop [
    feh vlc rhythmbox alsa-utils
    pinentry-gnome3
    # GPU-accelerated apps wrapped with nixGL for Ubuntu
    (config.lib.nixGL.wrap pkgs.ghostty)
    (config.lib.nixGL.wrap pkgs.google-chrome)
    # Wine: wineWow64Packages bundles both 32-bit and 64-bit support
    pkgs.wineWow64Packages.waylandFull
    pkgs.winetricks
    pkgs.gnomeExtensions.runcat
    pkgs.hackgen-nf-font
  ];

  # ── Git ───────────────────────────────────────────────────────────────────

  programs.git = {
    enable = true;
    userName = "eggplants";
    # userEmail and signingKey are populated dynamically via home.activation.gitFromGpg
    signing.signByDefault = true;
    settings = [
      # Two credential.helper entries: clear default then set gh
      { credential.helper = ""; }
      { credential.helper = "!/usr/bin/env gh auth git-credential"; }
      {
        commit.gpgsign = true;
        core.editor = "nano";
        "gpg".program = "gpg";
        help.autocorrect = 1;
        pull.rebase = false;
        push.autoSetupRemote = true;
        rebase.autosquash = true;
        "url \"git@codeberg.org:\"".pushInsteadOf = [
          "git://codeberg.org/"
          "https://codeberg.org/"
        ];
      }
    ];
  };

  # ── Docker (rootless) ─────────────────────────────────────────────────────

  systemd.user.services.docker = {
    Unit = {
      Description = "Docker Application Container Engine (Rootless)";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${pkgs.docker}/bin/dockerd-rootless.sh";
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

  # Derive email and signing key from GPG keyring after each switch
  home.activation.gitFromGpg = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ${pkgs.gnupg}/bin/gpg --list-secret-keys &>/dev/null 2>&1; then
      _key=$(${pkgs.gnupg}/bin/gpg --list-secret-keys | tac | grep -m1 -B1 '^sec' | head -1 | awk '$0=$1')
      _email=$(${pkgs.gnupg}/bin/gpg --list-keys | grep -Em1 '^uid' | rev | cut -f1 -d' ' | tr -d '<>' | rev)
      [[ -n "$_key"   ]] && ${pkgs.git}/bin/git config --global user.signingkey "$_key"
      [[ -n "$_email" ]] && ${pkgs.git}/bin/git config --global user.email    "$_email"
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
        "gh" = "latest";
        "asdf:troydm/asdf-roswell" = "latest";
      };
    };
    settings = {
      # Avoid compiling Ruby from source
      ruby.compile = false;
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
    };

    completionInit = ''
      autoload -U compinit && compinit
      zstyle ':completion:*' menu select
      zstyle ':completion:*:default' list-colors "''${(s.:.)LS_COLORS}"
    '';

    initExtra = ''
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
      fpath+=("${pkgs.pure}/share/zsh/site-functions")
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

  # One-time Wine prefix initialization; skipped if ~/.wine already exists
  # or if no display is available (activation runs during home-manager switch).
  home.activation.wineSetup = lib.mkIf isDesktop (lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! [[ -d $HOME/.wine ]] && [[ -n "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" ]]; then
      ${pkgs.wineWow64Packages.waylandFull}/bin/wineboot --init
      ${pkgs.winetricks}/bin/winetricks -q \
        allfonts gmdls dmsynth directmusic dsound devenum fakejapanese_ipamona
      ${pkgs.wineWow64Packages.waylandFull}/bin/wine reg add \
        "HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\RPG_RT.exe\\X11 Driver" \
        /v ClientSideWithRender /t REG_SZ /d N
    fi
  '');

  # ── Fonts ─────────────────────────────────────────────────────────────────

  fonts.fontconfig.enable = lib.mkIf isDesktop true;

  # ── GNOME settings (desktop only) ────────────────────────────────────────

  dconf.settings = lib.mkIf isDesktop {
    "org/gnome/desktop/default-applications/terminal" = {
      exec = "ghostty";
      exec-arg = "";
    };
    "org/gnome/shell" = {
      enabled-extensions = [ "runcat@kolesnikov.se" ];
    };
  };

  # ── VSCode (desktop only) ─────────────────────────────────────────────────

  programs.vscode = lib.mkIf isDesktop {
    enable = true;
    # ms-vscode-remote.remote-containers is not in nixpkgs; install manually after switch:
    #   code --install-extension ms-vscode-remote.remote-containers
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
