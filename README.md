# LuxPower Inverter / Octopus Time-of-use Tariff Integration

Hugely WIP, this is not finished or useful yet.

This will be a Ruby script to parse Octopus tariff prices and control a LuxPower ACS inverter according to rules you specify.

The particular use-case of this is to charge your home batteries when prices are cheap, and use that power at peak times.

## Installation

You'll need Ruby - at least 2.1 should be fine, which can be found in all good Linux distributions. Git is installed here too so you can clone the repository.

```
sudo apt-get install ruby ruby-bundler git
```

Clone this repository to your machine:

```
git clone https://github.com/celsworth/octolux.git
```

Install dependencies with bundler. Using `.bundle/config`, this will install gems to `./vendor/bundle`, and so does not need root.

```
cd octolux
bundle install
```

Create a `config.ini` using the `doc/config.ini.example` as a template. This script needs to know:

* where to find your Lux inverter, host and port.
* the serial numbers of your inverter and datalogger (the plug-in WiFi unit), which are normally printed on the sides.
* which Octopus tariff you're on, AGILE-18-02-21 is my current one for Octopus Agile.
* an API key to get tariff data from Octopus with. This can be generated in your Octopus Account page.

## Usage

TBD. This is not a finished script, don't just blindly run it.

The design is that this script is intended to be run every half an hour, just after the tariff price has changed. Running it in cron on the hour and half-hour should be fine.

The first thing it does is check if you have up-to-date tariff data; if not it fetches some and stores it in `tariff_data.json`.
