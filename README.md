shadowsocks-websocket-luvit
===========================

shadowsocks-websocket-luvit is a lightweight tunnel proxy which can help you get through
firewalls.  It is a port of [shadowsocks](https://github.com/clowwindy/shadowsocks), but
through a different protocol.

shadowsocks-websocket-luvit uses WebSocket instead of raw socket,
so it can be deployed on [heroku](https://www.heroku.com/).

Notice that the protocol is INCOMPATIBLE with the origin shadowsocks.

Usage
-----

    $ heroku create --buildpack https://github.com/mrluanma/heroku-buildpack-luvit.git
    Creating aqueous-harbor-3464... done, stack is cedar
    BUILDPACK_URL=https://github.com/mrluanma/heroku-buildpack-luvit.git

Push the code to heroku.

```
$ git push heroku master
Initializing repository, done.
Counting objects: 21, done.
Delta compression using up to 4 threads.
Compressing objects: 100% (16/16), done.
Writing objects: 100% (21/21), 13.07 KiB | 0 bytes/s, done.
Total 21 (delta 2), reused 0 (delta 0)

-----> Fetching custom git buildpack... done
-----> luvit app detected
-----> Fetching Luvit version 0.7.0
-----> Discovering process types
       Procfile declares types -> web

-----> Compressing... done, 1.6MB
-----> Launching... done, v5
       http://aqueous-harbor-3464.herokuapp.com/ deployed to Heroku

To git@heroku.com:aqueous-harbor-3464.git
 * [new branch]      master -> master
```

While in beta, WebSocket functionality must be enabled via the Heroku Labs:

```
$ heroku labs:enable websockets
Enabling websockets for aqueous-harbor-3464... done
WARNING: This feature is experimental and may change or be removed without notice.
For more information see: https://devcenter.heroku.com/articles/heroku-labs-websockets
```

Set a few configs:

```
$ heroku config:set METHOD=rc4 KEY=foobar
Setting config vars and restarting aqueous-harbor-3464... done, v7
KEY:    foobar
METHOD: rc4
```

Then run:

```
$ luvit local.lua -s aqueous-harbor-3464.herokuapp.com -l 1080 -m rc4 -k foobar
"shadowsocks-websocket-luvit v0.9.7"
{ server = "aqueous-harbor-3464.herokuapp.com", method = "rc4", local_port = "1080", password = "foobar" }
"server listening at port 0.0.0.0:1080"
```

Change proxy settings of your browser into:

    SOCKS5 127.0.0.1:local_port

Troubleshooting
----------------

If there is something wrong, you can check the logs by:

    $ heroku logs -t --app aqueous-harbor-3464
