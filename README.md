# KiKi

a super-tiny multithreaded activitypub compliant microblogging platform, written entirely in bash.

## Why?

why not! also i wanted to learn how activitypub works

## You can write servers in bash?
Yes! although there's no support for LISTEN in bash, you can hook up the script to netcat to respond to http requests. see `./daemon.sh` and `./lib/httpd.sh`

## Features

| Feature              | Supported?           |
| -------------------- | -------------------- |
| Notes (Pub/Sub)      | :white_check_mark:   |
| Follows              | :white_check_mark:   |
| mia:Bite             | :white_check_mark:   |
| Likes                | :white_check_mark:   |
| Mastodon API         | :x:                  |
| Frontend             | :x:                  |
| Announce             | :x:                  |
| Emoji Reactions      | :x:                  |

# Installation
you need `openssl`, `jq`, `curl`, and `ncat` installed for this
```
git clone https://github.com/velzie/kiki
cd kiki
# edit config.sh to your liking
./ctl.sh db_init

# now you need to create the instance actor, used to send signed AP requests. You can fill in anything, just make sure the actor id is the same as what you put in config.sh as INSTANCEACTOR
./ctl.sh useradd
```

# Usage

This server has no frontend, nor does it implement any client-to-server APIs. All interactions must happen through editing the "database" or with ctl.sh

- `./daemon.sh` to start the server
- `./ctl.sh useradd` creates a user, make sure to add "pfp.png" and "banner.png" to `db/users/<userid>/`
- `./ctl.sh act post <userid> "content"` will post a note and send it to followers. It will not currently post Announce activities to foreign instances.
- `./ctl.sh act follow <userid> <remote actor url>`


Since it's so light, you might want to simply use it to run bots. If you do expose this to the web, keep in mind that bash is the most insecure out of all languages and run it as an isolated user.


thank you to shittykopper and harper/blueb for helping me understand the AP protocol
