# LAN Members
LAN Members is a web service provides a list of devices connected to LAN.

Features:

* User Accounts
* List members in LAN
* Record usage time and last time LAN used

## Requirement
This software needs these softwares:

* Ruby >=2.2.0
* MongoDB >= 3.0.6
* nmap
* iproute "ip" or net-tools "arp" (ordinarily, these are installed when OS was installed)
* cron
* (maybe) ruby-devlop package and C compiler to build needed gems

## Installation
Execute this to resolve dependencies:

	$ bundle

## Execute
Edit crontab:

	% crontab -e

and add this:

	*/10 * * * * PATH_TO_LAN_MEMBER/scan.sh 192.168.1.0/24

Cron executes arp-scan and writes the result to `/tmp/arp_scan` every 10 minutes.
Needed to rewrite network address to yours.

	$ mongodb --dbpath=db
	$ bundle exec rackup -p 4567

Then access <http://localhost:4567/> .

## License
[MIT License](http://opensource.org/licenses/MIT)
