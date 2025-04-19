#!/usr/bin/env bash

# FOR Ubuntu 24.04 noble

set -eux

IS_DESKTOP="$(apt list --installed 2>/dev/null | grep ubuntu-desktop -q && echo true || :)"

is_desktop () {
  [[ "$IS_DESKTOP" = true ]]
}

cd ~
mkdir -p .config
mkdir -p .gnupg
mkdir -p prog
mkdir -p _setup
pushd _setup

if ! [[ -f ~/.sec.key ]]; then
  echo "need: ~/.sec.key"
  exit 1
fi

is_desktop && {
  gsettings set org.gnome.desktop.lockdown disable-lock-screen 'true'
}

# apt
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
  byobu curl ca-certificates ffmpeg git gnupg2 \
  imagemagick jq network-manager-l2tp pass \
  pinentry-tty pkg-config unar vlc w3m wget zsh
sudo install -m 0755 -d /etc/apt/keyrings

is_desktop && {
  sudo apt install -y \
    feh ibus-mozc network-manager-l2tp-gnome rhythmbox
}

# for java
sudo apt install -y default-jre openjdk-21-jdk-headless maven

# jave
is_desktop && {
  wget http://jave.de/download/jave5.zip
  sudo unzip jave5.zip -d /usr/local/src/jave5
  wget http://jave.de/figlet/figletfonts40.zip
  sudo unzip figletfonts40.zip 'fonts/*' -d /usr/local/src/jave5
  rm {jave5,figletfonts40}.zip
  sudo install -m 755 /dev/stdin /usr/local/bin/jave <<'A'
#!/bin/bash
java -jar /usr/local/src/jave5/jave5.jar
A
}

# mozc
is_desktop && {
  ibus restart
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'jp'), ('ibus', 'mozc-jp')]"
}

# rancher desktop
# curl -s 'https://download.opensuse.org/repositories/isv:/Rancher:/stable/deb/Release.key' | gpg --dearmor |
#   sudo dd status=none of='/usr/share/keyrings/isv-rancher-stable-archive-keyring.gpg'
# echo 'deb [signed-by=/usr/share/keyrings/isv-rancher-stable-archive-keyring.gpg]'\
#      'https://download.opensuse.org/repositories/isv:/Rancher:/stable/deb/ ./' | 
#   sudo dd status=none of='/etc/apt/sources.list.d/isv-rancher-stable.list'
# sudo apt update
# sudo apt install rancher-desktop -y
# # https://github.com/rancher-sandbox/rancher-desktop/issues/4524#issuecomment-2079041512
# sudo ln -s /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fddock

# docker
if command -v wsl.exe &>/dev/null
then
  powershell.exe /c winget.exe install Docker.DockerDesktop || :
else
  # Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  
  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt install -U docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# google chrome
is_desktop && {
  wget 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'
  sudo apt install ./google-chrome-stable_current_amd64.deb -y
}

# Qfinder
is_desktop && {
  curl -s 'https://www.qnap.com/ja-jp/utilities/essentials' |
    grep -oEm1 'https://[^"]+/QNAPQfinderProUbuntux64[^"]+\.deb' | xargs wget
  sudo apt install ./QNAPQfinderProUbuntux64*.deb -y
}

# import key
gpg --list-keys | grep -qE '^ *EE3A' || {
  export GPG_TTY="$(tty)"
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  if is_desktop; then
    echo "pinentry-program $(which pinentry-gnome3)" > ~/.gnupg/gpg-agent.conf
  else
    echo "pinentry-program $(which pinentry-tty)" > ~/.gnupg/gpg-agent.conf
  fi
  cat <<'A' >> ~/.gnupg/gpg-agent.conf
enable-ssh-support
default-cache-ttl 34560000
max-cache-ttl 34560000
A
  touch ~/.gnupg/sshcontrol
  chmod 600 ~/.gnupg/*
  chmod 700 ~/.gnupg
  gpgconf --kill gpg-agent
  sleep 3s
  cat ~/.sec.key | gpg --allow-secret-key --import
  gpg --list-key --with-keygrip | grep -FA1 '[SA]' | awk -F 'Keygrip = ' '$0=$2' > ~/.gnupg/sshcontrol
  pass init "$(gpg --with-colons --list-keys | awk -F: '$1=="fpr"{print$10;exit}')"
  gpg-connect-agent updatestartuptty /bye
  # `gpg --export-ssh-key w10776e8w@yahoo.co.jp > ssh.pub` and copy to server's ~/.ssh/authorized_keys
}

# code
is_desktop && {
  wget --trust-server-names -O code_latest.deb 'https://go.microsoft.com/fwlink/?LinkID=760868'
  sudo apt install ./code_latest.deb -y
}

# nanorc
[[ -d ~/.nano ]] || {
  git clone --depth 1 --single-branch 'https://github.com/serialhex/nano-highlight' ~/.nano
}
cat <<'A'>~/.nanorc
include "~/.nano/*.nanorc"

set autoindent
set constantshow
set linenumbers
set tabsize 4
set softwrap

# Color
set titlecolor white,red
set numbercolor white,blue
set selectedcolor white,green
set statuscolor white,green
A

# mise
curl https://mise.run | sh
echo 'eval "$($HOME/.local/bin/mise activate bash)"' >>~/.bashrc
echo 'eval "$($HOME/.local/bin/mise activate zsh)"' >>~/.zshrc
eval "$($HOME/.local/bin/mise activate ${SHELL/*\/})"

# steam
# is_desktop && {
#   wget 'https://cdn.akamai.steamstatic.com/client/installer/steam.deb'
#   sudo apt install ./steam.deb -y
# }

# python
command -v python 2>/dev/null || {
  mise use --global python@latest
  pip install pipx
  pipx ensurepath
  export PATH="$HOME/.local/bin:$PATH"
  pipx install getjump yt-dlp
}

# ruby
command -v ruby 2>/dev/null || {
  sudo apt install -y \
    gcc make autoconf patch build-essential rustc libssl-dev \
    libyaml-dev libreadline6-dev zlib1g-dev libgmp-dev libncurses5-dev \
    libffi-dev libgdbm6 libgdbm-dev libdb-dev uuid-dev
  mise use --global ruby@latest
}

# node
command -v node 2>/dev/null || {
  mise use --global node@latest
}

# gh
command -v gh 2>/dev/null || {
  mise use --global gh@latest
}

# rust
curl 'https://sh.rustup.rs' | sh -s -- -y
source ~/.cargo/env

# alacritty
is_desktop && {
  apt install -y \
    cmake g++ pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev
  (
    git clone --depth 1 -b graphics --single-branch https://github.com/ayosec/alacritty
    cd alacritty
    cargo build --release

    sudo tic -xe alacritty,alacritty-direct ./extra/alacritty.info
    infocmp alacritty || sudo tic -xe alacritty,alacritty-direct ./extra/alacritty.info
  
    sudo cp ./target/release/alacritty /usr/local/bin
    sudo cp ./extra/logo/alacritty-term.svg /usr/share/pixmaps/Alacritty.svg
    sudo desktop-file-install ./extra/linux/Alacritty.desktop
    sudo update-desktop-database
  )

  sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/local/bin/alacritty 50

  mkdir -p ~/.config/alacritty
  curl -o- 'https://codeload.github.com/alacritty/alacritty-theme/tar.gz/refs/heads/master' |
    tar xzf - alacritty-theme-master/themes
  mv alacritty-theme-master ~/.config/alacritty
  echo $'[general]\nimport = [' >> ~/.config/alacritty/alacritty.toml
  find ~/.config/alacritty/alacritty-theme-master/themes -type f -name '*toml' |
    sed 's/^.*/  # "&",/' >> ~/.config/alacritty/alacritty.toml
  echo ']' >> ~/.config/alacritty/alacritty.toml

  # hackgen
  curl -s 'https://api.github.com/repos/yuru7/HackGen/releases/latest' |
    grep -oEm1 'https://.*/HackGen_NF_v.*.zip' | xargs wget
  unar HackGen_NF_v*.zip
  mv ./HackGen_NF_v*/ hackgen
  sudo mv ./hackgen /usr/share/fonts/truetype/
  cat <<'A'>>~/.config/alacritty/alacritty.toml
[font]
size = 10.0

[font.bold]
family = "HackGen Console NF"
style = "Bold"

[font.bold_italic]
family = "HackGen Console NF"
style = "Bold Italic"

[font.italic]
family = "HackGen Console NF"
style = "Italic"

[font.normal]
family = "HackGen Console NF"
style = "Regular"
A
}

# xclicker
is_desktop && {
  curl -s 'https://api.github.com/repos/robiot/xclicker/releases/latest' |
    grep -oEm1 'https://.*/xclicker_[^_]+_amd64.deb' | xargs wget
  sudo apt install ./xclicker_*_amd64.deb -y
}

# go
command -v go 2>/dev/null || {
  mise use --global go@latest
}

# clisp
command -v ros 2>/dev/null || {
  curl -s 'https://api.github.com/repos/roswell/roswell/releases/latest' |
    grep -oEm1 'https://.*_amd64.deb' | xargs wget
  sudo apt install ./roswell_*_amd64.deb
  ros install sbcl-bin
}

# wine
is_desktop && {
  CODENAME="$(lsb_release -c | cut -f2)"
  sudo dpkg --add-architecture i386
  sudo apt install libfaudio0 -y
  sudo mkdir -pm755 /etc/apt/keyrings
  sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
  sudo wget -NP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/ubuntu/dists/${CODENAME}/winehq-${CODENAME}.sources"
  sudo apt update
  sudo apt install --install-recommends winehq-devel winetricks -y
  WINEARCH=win32 winecfg
  winetricks -q allfonts
}

# git
[[ -f ~/.gitconfig ]] || {
  gh auth login -p https -h gitHub.com -w <<<y
  gh auth setup-git
  git_email="$(
    gpg --list-keys | grep -Em1 '^uid' |
      rev | cut -f1 -d ' ' | tr -d '<>' | rev
  )"
  git config --global commit.gpgsign true
  git config --global core.editor nano
  git config --global gpg.program "$(which gpg)"
  git config --global help.autocorrect 1
  git config --global pull.rebase false
  git config --global push.autoSetupRemote true
  git config --global rebase.autosquash true
  git config --global user.email "$git_email"
  git config --global user.name eggplants
  git config --global user.signingkey "$(
    gpg --list-secret-keys | tac | grep -m1 -B1 '^sec' | head -1 | awk '$0=$1'
  )"
  cb_prefix="url.git@codeberg.org:"
  git config --global --remove-section "$gb_prefix" || :
  git config --global "$cb_prefix".pushInsteadOf "git://codeberg.org/"
  git config --global --add "$cb_prefix".pushInsteadOf "https://codeberg.org/"
}

# runcat
is_desktop && {
  wget https://github.com/win0err/gnome-runcat/releases/latest/download/runcat@kolesnikov.se.shell-extension.zip
  gnome-extensions install ./runcat@kolesnikov.se.shell-extension.zip --force
  gdbus call --session \
             --dest org.gnome.Shell.Extensions \
             --object-path /org/gnome/Shell/Extensions \
             --method org.gnome.Shell.Extensions.InstallRemoteExtension \
             "runcat@kolesnikov.se"
}

# sheldon
curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh |
  bash -s -- --repo rossmacarthur/sheldon --to ~/.local/
sheldon init --shell zsh <<<y
sheldon add --github zdharma/fast-syntax-highlighting fast-syntax-highlighting
sheldon add --github zdharma-continuum/history-search-multi-word history-search-multi-word
sheldon add --github zsh-users/zsh-autosuggestions zsh-autosuggestions
sheldon add --github zsh-users/zsh-completions zsh-completions
sheldon add --use async.zsh pure.zsh --github sindresorhus/pure pure

cat <<'A' >>~/.zshrc
eval "$(sheldon source)"

# if (which zprof > /dev/null) ;then
#   zprof | less
# fi
A

# zsh
[[ "$SHELL" = "$(which zsh)" ]] || chsh -s "$(which zsh)"
cat <<'A' >.zshrc.tmp
#!/usr/bin/env zsh

# load zprofile
[[ -f ~/.zprofile ]] && source ~/.zprofile

# completion
zstyle ':completion:*' menu select

# enable opts
setopt correct
setopt autocd
setopt nolistbeep
setopt aliasfuncdef
setopt appendhistory
setopt histignoredups
setopt sharehistory
setopt extendedglob
setopt incappendhistory
setopt interactivecomments
setopt prompt_subst

unsetopt nomatch

# alias
alias ll='ls -lGF --color=auto'
alias ls='ls -GF --color=auto'

# save cmd history up to 100k
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
HISTFILESIZE=2000
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search

# enable less to show bin
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# enable colorized prompt
case "$TERM" in
  xterm-color | *-256color) color_prompt=yes ;;
esac

# enable colorized ls
export LSCOLORS=gxfxcxdxbxegedabagacag
export LS_COLORS='di=36;40:ln=35;40:so=32;40:pi=33;40:ex=31;40:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;46'
zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"

export JAVA_HOME="/usr/lib/jvm/default-java"
export PATH="$PATH:$JAVA_HOME/bin"
export CLASSPATH=".:$JAVA_HOME/jre/lib:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar"
export M2_HOME="/opt/maven"
export MAVEN_HOME="/opt/maven"
export PATH="$PATH:$M2_HOME/bin"

export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/.config/Code/User/globalStorage/ms-vscode-remote.remote-containers/cli-bin"

unset SSH_AGENT_PID
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
fi
export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye >/dev/null

A

cat ~/.zshrc >>.zshrc.tmp
mv .zshrc.tmp ~/.zshrc

cat <<'A' >.zshenv.tmp
#!/usr/bin/env zsh

# zmodload zsh/zprof && zprof
A
cat ~/.zshenv >>.zshenv.tmp
mv .zshenv.tmp ~/.zshenv

byobu-enable
echo '_byobu_sourced=1 . /usr/bin/byobu-launch 2>/dev/null || true' > ~/.zprofile

sudo apt autoremove -y
sudo apt autoclean -y

rm ~/.sec.key
popd
rm -rf _setup

is_desktop && {
  gsettings set org.gnome.desktop.lockdown disable-lock-screen 'false'
}

shutdown -r 1
