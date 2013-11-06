# Postbal

Postbal is an outbound transport load balancer for Postfix.
It allows you to distribute your outbound mail traffic across
multiple IP addresses.



## Dependencies

Before installing Postbal, you will need to install the following
dependencies:

1. Postfix with TCP Tables enabled.

    Make sure it is built with tcp tables support:

    ```bash
    $ postconf -m
    btree
    cidr
    environ
    fail
    hash
    internal
    ldap
    memcache
    nis
    proxy
    regexp
    static
    tcp
    texthash
    unix
    ```

2. The List::util::WeightedRoundRobin Perl Module

    ```bash
    $ cpan install /List::util::WeightedRoundRobin/
    ```

    > Note: you may have to upgrade to CPAN 2.0 to install this module.



## Installation

Installing Postbal is easy. Simply copy `postbal.cf` and `postbal.pl` to `/etc/postfix`.



## Configuration

### 1. IP Addresses

You will need to configure your network interfaces to make IP addresses available
to the outbound SMTP transports in Postfix.

An easy way to accomplish this is to create a block of (internal) IP addresses via
IP aliasing, and then create NAT rules on your firewall that will convert each
internal IP address to an external IP address.

### 2. /etc/postfix/master.cf

In Postfix's master configuration file, you will need to define the Postbal service,
and also setup all of your outbound SMTP transports.

The configuration of the Postbal service is easy:

```
# Postbal TCP Transport Maps Server
#
127.0.0.1:23000 inet n n n - 0 spawn
    user=nobody argv=/etc/postfix/postbal.pl
```

On the other hand, setting up the SMTP transports can be a bit tedious.
If you need to enforce rate limiting, or control concurrency settings,
you can do it on a per-transport basis.

```
# Outbound SMTP transports
#
smtp0 unix - - n - - smtp
    -o syslog_name=postfix-smtp0
    -o smtp_helo_name=FQDN
    -o smtp_bind_address=IP

smtp1 unix - - n - - smtp
    -o syslog_name=postfix-smtp1
    -o smtp_helo_name=FQDN
    -o smtp_bind_address=IP
```

### 3. /etc/postfix/postbal.cf

The next step is to configure the load balancer. All you have to do
is list the transports that you want to use, and assign a weight to them:

```
{1}smtp0:
{1}smtp1:
```

### 4. /etc/postfix/main.cf

Once you have the Postbal service and SMTP transports setup, append the
following block of text to Postfix's main configuration file. This will
allow Postfix to utilize the load balancer.

```
# Use Postbal TCP Transport Maps
# see /etc/postfix/master.cf for service configuration
#
transport_maps = tcp:127.0.0.1:23000
127.0.0.1:23000_time_limit = 3600s
```


## Other Files

### /tmp/postbal.dat

This file is created as a side effect of running Postbal. It contains the last state of the
program so that it can pick up where it left off after a crash or a restart.

> Warning: if Postbal cannot create this file, you're gonna have a bad time.



## Testing

### Command Line

```bash
$ ./postbal.pl
a
400 error:invalid_request
get asdfasd
200 smtp0:
```

### Telnet

```bash
$ telnet localhost 23000
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
a
400 error:invalid_request
get asdfasd
200 smtp0:
```

### Postfix

```bash
$ postmap -q "dummy" tcp:127.0.0.1:23000
220 smtp0:
```



## Logging

Postbal logs to the mail syslog facility and associates itself with Postfix. This makes is simple to
follow the behavior of your mail server.

    Sep 2 12:50:05 myserver postfix/postbal[2076]: Postbal starting, configuration /etc/postfix/postbal.cf, recovery /tmp/postbal.dat
    Sep 2 12:50:05 myserver postfix/postbal[2076]: Using 'smtp0:' Transport Service
    Sep 2 12:50:05 myserver postfix-smtp0/smtp[2016]: 3CA964C0004: to=<example@domain.org>, relay=domain.org[XXXXXXXXX]:25, delay=2, delays=0.03/0.01/0.18/1.8, dsn=2.0.0, status=sent (250 OK id=1T86oe-0005tU-E9)



## Load Balancing Algorithm

Only weighted round robin is supported at this time.



## Caveats

1. The TCP transport map service operates in catch-all mode. This may prevent relays from working.
2. The Postfix queue manager requests a transport for each email address. If several emails are going
to the same address, it may use the transport more than once.
3. The transport map service seems to receive requests at random times in between deliveries. This
causes some of the transports to be skipped that round.



## Credits

Postbal is based on ideas proposed in various blogs:

- [Lachezar's Blog](http://marinovl.blogspot.com/2012/09/postfix-how-to-balance-outgoing-emails.html)
- [KutuKupret](http://www.kutukupret.com/2011/05/22/postfix-rotating-outgoing-ip-using-tcp_table-and-perl/)


