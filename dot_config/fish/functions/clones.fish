function clones
  set -l target_dir (command clones $argv)
  set -l exit_code $status

  if string match -q 'EDIT:*' -- $target_dir
    set -l repo_path (string replace 'EDIT:' '' -- $target_dir)
    if test -d "$repo_path"
      cd $repo_path
      $EDITOR .
      echo ""
      echo "Changed directory to: $repo_path"
      if test -d .git
        echo ""
        git status -sb
      end
    end
    return
  end

  if test $exit_code -eq 0; and test -d "$target_dir"
    cd $target_dir
    echo ""
    echo "Changed directory to: $target_dir"
    if test -d .git
      echo ""
      git status -sb
    end
  end
end
