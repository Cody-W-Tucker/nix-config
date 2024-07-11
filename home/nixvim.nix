{ config, nixvim, pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
    };
    autoCmd = [
      {
        event = [ "BufEnter" ];
        pattern = [ "*.md" ];
        command = "PencilSoft | Goyo";
      }
    ];
    plugins = {
      telescope.enable = true;
      treesitter.enable = true;
      lsp.enable = true;
      direnv.enable = true;
    };
    extraPlugins = with pkgs.vimPlugins; [
      limelight-vim
      # vim-litecorrect
      vim-pencil
      vim-wordy
      goyo-vim
      vim-LanguageTool
      thesaurus_query-vim
      vim-wordy
      # writegood
    ];
    extraConfigLua = ''
            function! s:goyo_enter()
        let b:quitting = 0
        let b:quitting_bang = 0
        autocmd QuitPre <buffer> let b:quitting = 1
        cabbrev <buffer> q! let b:quitting_bang = 1 <bar> q!
      endfunction

      function! s:goyo_leave()
        " Quit Vim if this is the only remaining buffer
        if b:quitting && len(filter(range(1, bufnr('$')), 'buflisted(v:val)')) == 1
          if b:quitting_bang
            qa!
          else
            qa
          endif
        endif
      endfunction

      autocmd! User GoyoEnter call <SID>goyo_enter()
      autocmd! User GoyoLeave call <SID>goyo_leave()
    '';
  };
}
