# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# java related settings
export JAVA_11_HOME="/opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home"

# my custom aliases
alias 20='nvm use 20.10.0'
alias 22='nvm use 22.15.0'
alias java11='export JAVA_HOME=$JAVA_11_HOME'
# other useful shortcuts
alias ask='python applications/start_conversation.py'
alias ask2='python applications/start_curated_conversation.py'

#default to java11
java11

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# exported paths
export ZSH="$HOME/.oh-my-zsh"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/ruby/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/ruby/lib/pkgconfig"
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:/Users/dragoscampean/.local/bin
export CPLUS_INCLUDE_PATH=/opt/homebrew/include
export PYENV_VIRTUALENV_DISABLE_PROMPT=1
export NODE_COMPILE_CACHE=~/.cache/nodejs-compile-cache

plugins=(
	git
	colorize
	zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

source ~/powerlevel10k/powerlevel10k.zsh-theme

# goenv
eval "$(goenv init -)"