{ config, lib, pkgs, vim-nord, vim-surround, vim-commentary, vim-easy-align, fzf-vim, vim-fugitive, vim-nix, vim-terraform, vim-go, ... }:

with lib;

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Enable Python support
    withPython3 = true;

    # Additional Python packages for Neovim
    extraPython3Packages = ps: with ps; [
      pynvim # Python client for neovim
      black # Python formatter
      flake8 # Python style checker
    ];

    # Additional packages for Neovim
    extraPackages = with pkgs; [
      ripgrep # Required for various search plugins
      fd # Alternative to find, used by some plugins
      fzf # Required for fzf-vim plugin
    ];

    # Neovim plugins using flake inputs
    plugins = lib.mapAttrsToList
      (name: path: {
        plugin = pkgs.vimUtils.buildVimPlugin {
          inherit name;
          src = path;
        };
        config = "";
      })
      {
        # UI Enhancements
        nord-vim = vim-nord;

        # Editing Tools
        inherit vim-surround;
        inherit vim-commentary;
        inherit vim-easy-align;

        # File Navigation
        inherit fzf-vim;

        # Git Integration
        inherit vim-fugitive;

        # Language Support
        inherit vim-nix;
        inherit vim-terraform;
        inherit vim-go;
      };

    # Main Neovim configuration
    extraConfig = ''
      "" Shavakan's Neovim Configuration
      "" Adapted from original vimrc
      """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

      " Basic settings
      syntax enable
      syntax sync fromstart
      filetype plugin indent on

      " Editor settings
      set mouse=a                             " -- mouse cursor on
      set noet bs=2 ts=4 sw=8 sts=0           " -- tabstop
      set noai nosi hls is ic cf ws scs magic " -- search
      set nu ru sc wrap ls=2 lz               " -- appearance
      set expandtab                           " -- tab as spaces
      set clipboard=unnamed                   " -- clipboard usage on macOS

      " Encoding and file format
      set fenc=utf-8 ff=unix ffs=unix,dos,mac
      set fencs=utf-8,cp949,cp932,euc-jp,shift-jis,big5,latin2,ucs2-le

      " Set colorscheme
      colorscheme nord
      hi Normal ctermbg=none
      hi NonText ctermbg=none

      " Easy-align configuration
      " Start interactive EasyAlign in visual mode (e.g. vipga)
      xmap ga <Plug>(EasyAlign)
      " Start interactive EasyAlign for a motion/text object (e.g. gaip)
      nmap ga <Plug>(EasyAlign)

      " Cursor position restore
      autocmd BufReadPost *
        \ if line("'\"") > 0 && line("'\"") <= line("$") |
        \   exe "norm g`\"" |
        \ endif
        
      " Custom filetype detection
      autocmd BufRead,BufNewFile *.capnp set filetype=capnp
      autocmd BufRead,BufNewFile *.tf set filetype=terraform
      
      " Git commit settings
      autocmd FileType gitcommit DiffGitCached | wincmd L | wincmd p
      
      " Language-specific settings
      " Python
      autocmd FileType python setlocal tabstop=8 shiftwidth=4 softtabstop=4 expandtab
      
      " YAML
      autocmd FileType yaml setlocal tabstop=8 shiftwidth=2 softtabstop=2 expandtab
      
      " Shell
      autocmd FileType sh setlocal tabstop=2 shiftwidth=4 softtabstop=4 expandtab
      
      " HTML
      autocmd FileType html setlocal tabstop=8 shiftwidth=2 softtabstop=2 expandtab
      
      " CSS
      autocmd FileType css setlocal tabstop=8 shiftwidth=4 softtabstop=4 expandtab
      
      " JavaScript
      autocmd FileType javascript setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
      let g:javascript_plugin_jsdoc = 1
      let g:javascript_plugin_flow = 1
      
      " JSX
      autocmd FileType jsx syntax sync fromstart
      autocmd FileType jsx setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
      
      " Vue
      autocmd FileType vue syntax sync fromstart
      autocmd FileType vue setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
      
      " Terraform
      autocmd FileType terraform setlocal tabstop=8 shiftwidth=2 softtabstop=2 expandtab commentstring=#%s
      let g:terraform_align=1
      let g:terraform_remap_spacebar=1
      
      " C
      autocmd FileType c setlocal tabstop=8 shiftwidth=4 softtabstop=4 expandtab
      
      " C++
      autocmd FileType cpp setlocal tabstop=8 shiftwidth=4 softtabstop=4 expandtab
      
      " Java
      autocmd FileType java setlocal tabstop=4 shiftwidth=4 softtabstop=0 noexpandtab
      
      " PHP
      autocmd FileType php setlocal tabstop=8 shiftwidth=4 softtabstop=4 expandtab
      
      " ASP
      autocmd FileType asp setlocal tabstop=8 shiftwidth=4 softtabstop=4 expandtab
      
      " JSP
      autocmd FileType jsp setlocal tabstop=8 shiftwidth=4 softtabstop=4 expandtab
      
      " Ruby
      autocmd FileType ruby setlocal tabstop=8 shiftwidth=4 softtabstop=4 expandtab
      
      " CapnProto
      autocmd FileType capnp setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
      
      " Protocol Buffers
      autocmd BufRead,BufNewFile *.proto set filetype=proto
      autocmd FileType proto setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab
      
      " gRPC
      autocmd BufRead,BufNewFile *.grpc.* set filetype=proto
      
      " Text
      autocmd FileType text setlocal textwidth=80
    '';
  };
}
