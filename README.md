# LAN Members
LAN Members monitors users and usage of a LAN.

Features:

* User Accounts
* List members in a LAN
* Record an usage time and a last used time per user

Currently, only Japanese is supported language.

## Requirement
This software needs these softwares:

* Ruby >=2.2.0
* MongoDB >= 3.0.6
* nmap
* iproute "ip" or net-tools "arp"
* cron
* "ruby-develop" package 
* C compiler to build required gems

## Installation
Execute this to resolve dependencies:

	$ bundle

If you DO NOT want to install gems to system, you can install them into another directory:

	$ bundle install --path vendor/bundle

## Execute

Edit crontab:

	% crontab -e

and add this:

	*/10 * * * * PATH_TO_LAN_MEMBER/scan.sh 192.168.1.0/24

Cron executes arp-scan and writes a result to `/tmp/arp_scan` every 10 minutes.
You have to rewrite the network address to an appropriate one for your network.

Launch a mongodb server:

	$ mongodb --dbpath=db

, or you can use docker-compose for setup mongodb:

	$ docker-compose up -d

Finally, start an application: 

	$ bundle exec rackup -p 4567

Now, you can access <http://localhost:4567/>.

## License
[MIT License](http://opensource.org/licenses/MIT)
