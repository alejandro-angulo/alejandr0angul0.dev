+++
title = "Running Travis CI Locally"
date = 2017-12-18T05:02:42-00:00
author = "alejandro"
tags = ["procrastination"]
+++

### TL;DR

- Travis build was failing.
- Found a possible fix, but I didn't want to push commits just to check if it would work.
- Ran [travis-build](https://github.com/travis-ci/travis-build) in a Docker container to test the fix.

---

I accidentally pushed a change to kilonull that added the word "test" in the site's title tag. I pushed [another
commit](https://github.com/vacuus/kilonull/commit/455f52f97f508f4c2b2bd0cec6cad33f7eb8e413) to remove the extra text and pulled on
my server. About 5 minutes later I received an email telling me my build on Travis had
[failed](https://travis-ci.org/vacuus/kilonull/builds/317863434).

```bash
# ...snip...
Error: could not determine PostgreSQL version from '10.1'

    ----------------------------------------
Command "python setup.py egg_info" failed with error code 1 in /tmp/pip-build-wq2uqxzp/psycopg2/

The command "pip install -r requirements.txt" failed and exited with 1 during .

Your build has been stopped.
```

Well at least _my_ code didn't break anything. But hey, it's a Sunday and I have chores to ignore. Let's look into this. I googled
the error and stumbled upon a [comment on Github](https://github.com/psycopg/psycopg2/issues/594#issuecomment-346514672) stating
that the fix was to update the psycopg2 requirement to 2.7.1 (the current latest version). Great, that should be an easy fix. But
hang on, I have all these chores to ignore. I can probably run Travis locally before pushing just to verify the fix. Let's look
into this.

Someone else (Ibrahim Ulukaya) was kind of enough to document how to [run Travis tests from a Docker
container](https://medium.com/google-developers/how-to-run-travisci-locally-on-docker-822fc6b2db2e). I followed his instructions
but I kept getting an error about being unable to load travis/support when I ran `travis compile`.

```bash
$ travis compile
/home/travis/.rvm/rubies/ruby-2.4.3/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:120:in 'require': cannot load such file -- travis/support (LoadError)
	from /home/travis/.rvm/rubies/ruby-2.4.3/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:120:in 'require'
	from /home/travis/.travis/travis-build/lib/travis/build.rb:1:in '<top (required)>'
	from /home/travis/.rvm/rubies/ruby-2.4.3/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:120:in 'require'
	from /home/travis/.rvm/rubies/ruby-2.4.3/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:120:in 'require'
	from /home/travis/.travis/travis-build/init.rb:11:in 'setup'
	from /home/travis/.rvm/gems/ruby-2.4.3/gems/travis-1.8.8/lib/travis/cli/command.rb:197:in 'execute'
	from /home/travis/.rvm/gems/ruby-2.4.3/gems/travis-1.8.8/lib/travis/cli.rb:64:in 'run'
	from /home/travis/.rvm/gems/ruby-2.4.3/gems/travis-1.8.8/bin/travis:18:in '<top (required)>'
	from /home/travis/.rvm/gems/ruby-2.4.3/bin/travis:23:in 'load'
	from /home/travis/.rvm/gems/ruby-2.4.3/bin/travis:23:in '<main>'
	from /home/travis/.rvm/gems/ruby-2.4.3/bin/ruby_executable_hooks:15:in 'eval'
	from /home/travis/.rvm/gems/ruby-2.4.3/bin/ruby_executable_hooks:15:in '<main>'
```

I found [another useful comment on Github](https://github.com/travis-ci/travis-ci/issues/8098#issuecomment-321507488) that
suggested specifying the path to the travis script from travis-support. Maybe I did something wrong when I followed the
instructions on Medium but this was working for me.

Here are the steps that worked for me. I hope this is useful for someone else someday.

First off, we'll need to decide on one of Travis's docker containers to run from. Available containers are [listed on
Quay](https://quay.io/organization/travisci). We'll want one of the containers named `travis-<some language>`. I copy-pasted from
the instructions in the Medium article so I ended up running everything under the `travis-jvm` container. In retrospect, I should
have used `travis-python` since I was dealing with a Python project. The command
`docker run -it -u travis quay.io/travisci/travis-jvm /bin/bash`
can be used to run the container (replace `travis-jvm` with whatever container is desired).

Before setting up `travis-build` we can choose which version of Ruby to work with. The latest stable version was 2.4.3 when I
checked so I decided to go with that.

```bash
rvm install 2.4.3 rvm use 2.4.3
```

Once Ruby is set up to our liking we can set up `travis-build`:

```bash
$ travis compile
/home/travis/.rvm/rubies/ruby-2.4.3/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:120:in 'require': cannot load such file -- travis/support (LoadError)
	from /home/travis/.rvm/rubies/ruby-2.4.3/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:120:in 'require'
	from /home/travis/.travis/travis-build/lib/travis/build.rb:1:in '<top (required)>'
	from /home/travis/.rvm/rubies/ruby-2.4.3/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:120:in 'require'
	from /home/travis/.rvm/rubies/ruby-2.4.3/lib/ruby/2.4.0/rubygems/core_ext/kernel_require.rb:120:in 'require'
	from /home/travis/.travis/travis-build/init.rb:11:in 'setup'
	from /home/travis/.rvm/gems/ruby-2.4.3/gems/travis-1.8.8/lib/travis/cli/command.rb:197:in 'execute'
	from /home/travis/.rvm/gems/ruby-2.4.3/gems/travis-1.8.8/lib/travis/cli.rb:64:in 'run'
	from /home/travis/.rvm/gems/ruby-2.4.3/gems/travis-1.8.8/bin/travis:18:in '<top (required)>'
	from /home/travis/.rvm/gems/ruby-2.4.3/bin/travis:23:in 'load'
	from /home/travis/.rvm/gems/ruby-2.4.3/bin/travis:23:in '<main>'
	from /home/travis/.rvm/gems/ruby-2.4.3/bin/ruby_executable_hooks:15:in 'eval'
	from /home/travis/.rvm/gems/ruby-2.4.3/bin/ruby_executable_hooks:15:in '<main>'
```

Unfortunately, it didn't work for me. Removing the branch flag from the clone command fixed it for me though. I suspect the actual
Travis CI service inserts the branch name based on what branch contained the commit triggering the build. We're doing this
manually though so we'll have to make a small adjustment to our build script. Go ahead and open it up in your favorite text editor
(vim). Find the definition for the `travis_run_checkout` function. Remove the branch flag (or specify a branch name if you want to
pull from something other than `master`) from the clone command inside the if block.

Run the `ci.sh` script with our modification again and you should be able to successfully clone your project and continue with the
rest of the build process. This is nice and all but the whole point in running Travis locally for me was so I could test changes
without having to make a commit. But `travis_run_checkout` is called every time our build script executes. We can make another
modification so we can test local changes without committing. Open `ci.sh` up again and go back to the definition of the
travis_run_checkout function. Before the `travis_fold end git.checkout` line there will be a `cd` command that tells the build
script to go to the location we pulled our repository to. Copy this line then go to the bottom of the script. Comment out the call
to `travis_run_checkout` and paste the `cd` command on the next line. Your hacked build script should look something like this:

```bash
EOFUNC_FINISH
# END_FUNCS
source $HOME/.travis/job_stages
travis_run_setup_filter
travis_run_configure
#travis_run_checkout
travis_cmd cd\ vacuus/kilonull --echo
travis_run_prepare
travis_run_disable_sudo
travis_run_export
travis_run_setup
travis_run_setup_casher
travis_run_setup_cache
travis_run_announce
travis_run_debug
travis_run_before_install
travis_run_install
travis_run_before_script
travis_run_script
travis_run_before_cache
travis_run_cache
travis_run_after_success
travis_run_after_failure
travis_run_after_script
travis_run_finish
echo -e "\nDone. Your build exited with $TRAVIS_TEST_RESULT."

travis_terminate $TRAVIS_TEST_RESULT
```

Now we have two copies of our repo in the container which might get a bit confusing. We can remove the repo at the location that
we manually cloned (not the one cloned as part of the build script inside `~/build`). Just remember to move the `ci.sh` script
before deleting your project's directory. We can now make changes to the copy of the repo inside the `~/build` directory and run
our hacked build script to test any changes. I updated my `requirements.txt`'s version for `psycopg2` and my build succeeded just
as I had hoped :) .

This process is pretty convoluted but I think I can automate this and include it a container for my project. But, maybe I'm better
off using something like Jenkins for CI if I'm so concerned with running my builds locally. At least I can feel like I did
something productive while avoiding my chores.
