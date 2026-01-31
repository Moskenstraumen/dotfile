#!/bin/bash

# this setup script does not require root priviledge
# BUT it installs some programs in $HOME/.local/bin
# make sure to add this path in your PATH or change it as you wish
INSTALLDIR=$HOME/.local/bin

# basic requirements
# if [ ! -x "$(command -v fusermount)" ]; then
# 	echo "fusermount is required to run .appimage"
# 	echo "Exiting..."
# 	exit 1
# fi
if [ ! -x "$(command -v curl)" ]; then
	echo "curl is required for pulling pre-compiled binaries from git release page"
	echo "Exiting..."
	exit 1
fi

# create symlinks of my dotfiles (will not override if already exists)
[ -d "$HOME/.config" ] || mkdir -p $HOME/.config
[ -d "$HOME/.config/nvim" ] || ln -s $HOME/dotfile/nvim $HOME/.config/nvim
[ -f "$HOME/.config/starship.toml" ] || ln -s $HOME/dotfile/starship.toml $HOME/.config/starship.toml
[ -d "$HOME/.config/zsh" ] || mkdir -p $HOME/.config/zsh
[ -f "$HOME/.config/zsh/alias.zsh" ] || ln -s $HOME/dotfile/zsh/alias.zsh $HOME/.config/zsh/alias.zsh

# installations of all the tools I need
[ -x "$(command -v cargo)" ] || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
mkdir -p $HOME/.local/bin
mkdir -p $HOME/.local/share $HOME/.local/lib
export PATH=${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}
[ -x "$(command -v starship)" ] || curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir $INSTALLDIR --yes
[ -x "$(command -v rg)" ] || cargo install ripgrep
[ -x "$(command -v fd)" ] || cargo install fd-find
if [ ! -x "$(command -v lazygit)" ]; then
	curl -Lo lazygit.tar.gz https://github.com/jesseduffield/lazygit/releases/download/v0.45.2/lazygit_0.45.2_$(uname -s)_$(uname -m).tar.gz
	mkdir lazygit
	tar -xvf lazygit.tar.gz -C lazygit
	mv lazygit/lazygit $INSTALLDIR
	rm -r lazygit lazygit.tar.gz
fi

# install neovim which is compiled for older systems
# if your system is relatively new, you can install it from:
# https://github.com/neovim/neovim/releases/tag/stable
if [ ! -x "$(command -v nvim)" ] || [ ! -d "$HOME/.local/share/nvim/runtime" ]; then
	curl -Lo nvim.tar.gz https://github.com/neovim/neovim-releases/releases/download/stable/nvim-linux-x86_64.tar.gz
	tar -xzf nvim.tar.gz
	cd nvim-linux-x86_64
	/bin/cp -rf bin/* $INSTALLDIR/
	/bin/cp -rf share/* $INSTALLDIR/../share
	/bin/cp -rf lib/* $INSTALLDIR/../lib
	cd ..
	rm -rf nvim-linux-x86_64 nvim.tar.gz
fi

# install tmux>=3.3 for allow-passthrough option
tmux_version=$(tmux -V 2>/dev/null | awk '{print $2}')
if [[ ! ${tmux_version: -1} =~ [0-9] ]]; then
	tmux_version="${tmux_version::-1}"
fi
if [ -z "$tmux_version" ]; then
	tmux_version="0.0"
fi
if [ "$(printf '%s\n' "$tmux_version" "3.3" | sort -V | head -n1)" = "$tmux_version" ] && [ "$tmux_version" != "3.3" ]; then
	curl -Lo tmux-3.5a.tar.gz https://github.com/tmux/tmux/releases/download/3.5a/tmux-3.5a.tar.gz
	tar -xvzf tmux-3.5a.tar.gz
	cd tmux-3.5a
	if pkg-config --cflags --libs libevent &>/dev/null; then
		./configure --prefix=$HOME/.local && make -j$(nproc)
	elif PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$HOME/.local/lib/pkgconfig pkg-config --cflags --libs libevent &>/dev/null; then
		./configure --prefix=$HOME/.local CFLAGS="-I$HOME/.local/include" LDFLAGS="-L$HOME/.local/lib" && make -j$(nproc)
	else
		curl -Lo libevent.tar.gz https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
		tar -xvzf libevent.tar.gz
		cd libevent
		mkdir build && cd build
		cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/.local
		make -j$(nproc)
		make install
		cd ../..
		./configure --prefix=$HOME/.local CFLAGS="-I$HOME/.local/include" LDFLAGS="-L$HOME/.local/lib" && make -j$(nproc)
	fi
	make install
	cd ..
	rm -rf tmux-3.5a tmux-3.5a.tar.gz
	echo "$(tmux -V) has been installed!"
fi
# tmux seems to be superior than xclip in terms of syncing up clipboards
# # install xclip
# if [ ! -x "$(command -v xclip)" ]; then
# 	wget https://sourceforge.net/projects/xclip/files/latest/download -O xclip.tar.gz
# 	tar -xzf xclip.tar.gz
# 	cd xclip-*
# 	./configure --prefix=$HOME/.local
# 	make && make install
# 	cd ..
# 	rm -rf xclip.tar.gz xclip-*
# fi

# finalize
if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' $HOME/.zshrc 2>/dev/null; then
	echo 'export PATH="$HOME/.local/bin:$PATH"' >> $HOME/.zshrc
fi
if [ -n "$ZSH_VERSION" ]; then
	source $HOME/.zshrc
else
	echo "Done. Restart your shell or run: source ~/.zshrc"
fi
