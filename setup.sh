#!/bin/bash
set -e

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NOCOLOR="\033[0m"
# avoids an edgecase where employees do not have 1password accounts set up
BC_RAW_1PASS_ID="CMUGFRT7Y5BRJMYKQIXJDO2654"

function abort {
    echo -e "\n${RED}Exiting early, please re-run after correcting errors!${NOCOLOR}"
    exit 1
}

function activate_brew {
    if ! command -v brew &> /dev/null; then
        echo -e "${GREEN}Activating Homebrew...${NOCOLOR}"
        eval "$(/opt/homebrew/bin/brew shellenv)"

        if [ ! -e ~/.profile ]; then
            touch ~/.zprofile
        fi
        if ! grep -q "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" ~/.zprofile; then
            echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile
        fi
    fi
}

if [ ! -e "/opt/homebrew/bin/brew" ]; then
    echo -e "${RED}Homebrew not found. Installing...${NOCOLOR}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo -e "${GREEN}Homebrew found. Updating/Upgrading...${NOCOLOR}"
    activate_brew
    brew update && brew upgrade && brew upgrade --cask && brew cleanup
fi

echo -e "\n${GREEN}### Installing packages ###${NOCOLOR}\n"
activate_brew

function brew_install {
    if [ ! -e "$2" ]; then
        echo -e "\nInstalling ${GREEN}$1${NOCOLOR}..."
        brew install $1
    else   
        echo -e "Skipping ${YELLOW}$1${NOCOLOR} - already installed"
    fi
}

brew_install "orbstack" "/Applications/OrbStack.app"
brew_install "gh" "/opt/homebrew/bin/gh"
brew_install "mas" "/opt/homebrew/bin/mas"
brew_install "stripe/stripe-cli/stripe" "/opt/homebrew/bin/stripe"
brew_install "mise" "/opt/homebrew/bin/mise"
brew_install "1password-cli" "/opt/homebrew/bin/op"

if [ ! -e "/Applications/Tailscale.app" ]; then
    echo -e "Installing ${GREEN}Tailscale${NOCOLOR}..."
    mas install 1475387142 || echo -e "${RED}Tailscale not installed - you'll need to do this from the Mac App Store manually${NOCOLOR}"
fi

echo -e "\n${GREEN}### Setting up SSH ###${NOCOLOR}\n"

if [ ! -d "~/.ssh" ]; then
    mkdir -p ~/.ssh
fi

if [ ! -e "/Users/$USER/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ]; then
    echo -e "${RED}1Password SSH Agent not found. Make sure you have 1Password installed, configured, and have turned on SSH Agent in it's developer settings area${NOCOLOR}"
    echo "See https://www.notion.so/bigcartel/Development-Machine-Setup-40e4c8bdfdac449b817e9b025f7bef09?pvs=4#197152faaa024522ba22221d49bed6a4"
    abort
else
    if ! awk -v RS='' '/Host \*\n  IdentityAgent/ { found=1; exit } END { if(found) exit 0; else exit 1 }' ~/.ssh/config; then
        cat <<EOF >> ~/.ssh/config
Host *
  IdentityAgent "/Users/$USER/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
EOF
    fi
fi

# pre-populate known_hosts file with correct GitHub keys
if [ -e ~/.ssh/known_hosts ]; then
    sed -i '' '/^github.com/d' ~/.ssh/known_hosts
fi
mkdir -p ~/.ssh
cat <<EOF >> ~/.ssh/known_hosts
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
EOF

echo -ne "${YELLOW}Testing GitHub ssh access...${NOCOLOR} "
ssh -q git@github.com > /dev/null 2>&1 || last_exit=$?
if [ $last_exit -eq 1 ]; then
    echo -e "${GREEN}Success${NOCOLOR}"
else
    echo -e "${RED}Failed${NOCOLOR}"
    echo "Make sure have configured your ssh key in 1password, added it to your GitHub Account, and enabled the 1password SSH Agent"
    echo "See https://www.notion.so/bigcartel/Development-Machine-Setup-40e4c8bdfdac449b817e9b025f7bef09?pvs=4#197152faaa024522ba22221d49bed6a4"
    abort
fi

echo -ne "${YELLOW}Testing 1Password CLI...${NOCOLOR} "
if op account get --account $BC_RAW_1PASS_ID > /dev/null 2>&1; then
    echo -e "${GREEN}Success${NOCOLOR}"
else
    echo -e "${RED}Failed${NOCOLOR}"
    echo "Make sure you have 1Password installed, configured, and have turned on CLI access in developer settings"
    abort
fi

# avoids an edgecase where employees do not have 1password accounts set up
echo -ne "${YELLOW}Testing Access to developer vaults...${NOCOLOR} "
if op --account $BC_RAW_1PASS_ID item get "Rails Secrets [admin]" > /dev/null 2>&1; then
    echo -e "${GREEN}Success${NOCOLOR}"
else
    echo -e "${RED}Failed${NOCOLOR}"
    echo "Make sure you have been granted access to the Development vault by a 1Password Admin"
    abort
fi

echo -e "\n${GREEN}### Establishing preferences ###${NOCOLOR}\n"

function ask_w_default {
    eval def=\$\{$2:="$3"\}
    echo -ne "${GREEN}$1${NOCOLOR} "
    if [ ! -z $def ]; then
        echo -ne "[$def] "
    fi
    read response
    if [ -z "$response" ]; then
        response=$def
    fi
    eval $2="$response"
    echo "export $2=\"$response\"" >> ~/.bc_profile
}

function get_prefs {
    ask_w_default "Where would you like BC code to live?" BC_HOME "~/code/bc"
    echo -e "\n${YELLOW}Note: You probably want to say yes unless you have significant dotfile mods you are afraid to lose.${NOCOLOR}"
    echo -e "${YELLOW}If you say no, you'll need to manually checkout dotmatrix and at least put it's helper scripts in your path${NOCOLOR}"
    ask_w_default "Setup standard BC dotfiles? (y/n)" BC_USE_DOTMATRIX "y"
}

if [ -e ~/.bc_profile ]; then
    eval $(cat ~/.bc_profile)
fi

get_prefs

if [ ! -e "$HOME/.gitconfig.local" ]; then
  echo -n "\n${GREEN}Setting up your git config...${NOCOLOR}"
  read -p "Enter your full name: " name
  git config -f ~/.gitconfig.local --add user.name "$name"
  read -p "Enter your email: " email
  git config -f ~/.gitconfig.local --add user.email "$email"
fi

echo -e "\n${GREEN}### Installing dev environment ###${NOCOLOR}\n"

if [ ! -e "$BC_HOME" ]; then
    mkdir -p "$BC_HOME"
fi

pushd "$BC_HOME" > /dev/null

if [ "$BC_USE_DOTMATRIX" != "y" ]; then
    echo -e "${YELLOW}Skipping dotmatrix install${NOCOLOR}"
else
    echo -e "${GREEN}Installing dotmatrix...${NOCOLOR}"

    if [ ! -e "$BC_HOME/dotmatrix" ]; then
        git clone git@github.com:bigcartel/dotmatrix.git
        pushd dotmatrix > /dev/null
        bin/install
    else
        pushd dotmatrix > /dev/null
        bin/upgrade
    fi

    popd
fi

echo -e "\n${GREEN}We'll now launch Orbstack. When prompted select docker and complete any signin/configuration steps"
echo -e "Return here when Orbstack is running to continue setup${NOCOLOR}\n"
echo -ne "${YELLOW}Press enter to launch Orbstack...${NOCOLOR}"
read
open -a OrbStack
echo -ne "${YELLOW}Press enter when you've completed the Orbstack setup...${NOCOLOR}"
read

echo -e "${GREEN}All base software installed and configured${NOCOLOR}"

if [ -e "$BC_HOME/compose-dev" ]; then
    echo -e "${YELLOW}compose-dev repo present. Not attempting redundant setup${NOCOLOR}"
else
    echo -e "${GREEN}Setting up compose dev...${NOCOLOR}"
    git clone git@github.com:bigcartel/compose-dev.git

    echo -e "${YELLOW}The final step is to cd to $BC_HOME/compose-dev and run ./setup.sh${NOCOLOR}"
    echo -e "${YELLOW}compose-dev is the base checkout of our docker-compose based dev environment${NOCOLOR}"
    echo -e "${YELLOW}The setup script will build container images and bootstap the actual dev environment${NOCOLOR}"
fi
