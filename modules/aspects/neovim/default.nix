{ den, ... }:
{
  den.aspects.neovim = {
    homeManager =
      { pkgs, ... }:
      {
        programs.neovim = {
          enable = true;
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
          withNodeJs = true;
          withPython3 = true;
          plugins = with pkgs.vimPlugins; [
            lazy-nvim
          ];
          extraPackages = with pkgs; [
            lua-language-server
            nil
            nixd
            stylua
            ripgrep
            fd
            tree-sitter
          ];
        };
        xdg.configFile."nvim/init.lua".text = ''
          vim.g.mapleader = " "
          vim.o.number = true
          vim.o.relativenumber = true
          vim.o.termguicolors = true
          vim.o.expandtab = true
          vim.o.shiftwidth = 2
          vim.o.tabstop = 2
          vim.o.clipboard = "unnamedplus"
          vim.keymap.set("n", "<leader>w", "<cmd>w<cr>")
          vim.keymap.set("n", "<leader>q", "<cmd>q<cr>")
        '';
      };
  };
}
