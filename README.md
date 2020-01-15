# LuxPower Inverter / Octopus Time-of-use Tariff Integration

This is a Ruby script to parse Octopus tariff prices and control a LuxPower ACS inverter according to rules you specify.

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

### Inverter Setup

By default, the datalogger plugged into the Lux sends statistics about your inverter to LuxPower in China. This is how their web portal and phone app knows all about you.

We need to configure it to open another port that we can talk to. Open a web browser to your datalogger IP (might have to check your DHCP server to find it) and login with username/password admin/admin. Click English in the top right :)

You should see:

![](doc/lux_run_state.png)

Tap on Network Setting in the menu. You should see two forms, the top one is populated with LuxPower's IP in China - the second one we can use. Configure it to look like the below and save:

![](doc/lux_network_setting.png)

After the datalogger reboots (this takes only a couple of seconds and does not affect the main inverter operation, it will continue as normal), port 4346 on your inverter IP is accessible to our Ruby script. You should be sure that this port is only accessible via your LAN, and not exposed to the Internet, or anyone can control your inverter.


## Usage

The design is that this script is intended to be run every half an hour, just after the tariff price has changed. Running it in cron on the hour and half-hour should be fine.

The first thing it does is check if you have up-to-date tariff data; if not it fetches some and stores it in `tariff_data.json`.

There is currently one simple hardcoded rule in `octolux.rb` - if the current Octopus price (inc VAT) is 5p or lower, enable AC charging. If it is higher, then disable it. If the inverter was already in the correct state then no action is taken. Therefore this is safe to run as often as you like.

This is still rather a proof of concept, so use with care. It will output some logging information to tell you what it is doing.

An example of the price being below 5p, so it enables AC charging:

```
~/src/octolux> ./octolux.rb
I, [2020-01-15T10:53:01.221311 #81551]  INFO -- : Current Octopus Unit Price: 4.0125p
D, [2020-01-15T10:53:01.221783 #81551] DEBUG -- : charge(true)
D, [2020-01-15T10:53:01.221813 #81551] DEBUG -- : update_register(21, 128, true)
D, [2020-01-15T10:53:01.221823 #81551] DEBUG -- : read_register(21)
D, [2020-01-15T10:53:02.059861 #81551] DEBUG -- : read_register 21 result = 62292
D, [2020-01-15T10:53:02.059941 #81551] DEBUG -- : set_register(21 62420)
```

An example of the price being above 5p, so it disables AC charging:

```
I, [2020-01-15T10:53:25.204004 #81782]  INFO -- : Current Octopus Unit Price: 8.2215p
D, [2020-01-15T10:53:25.204536 #81782] DEBUG -- : charge(false)
D, [2020-01-15T10:53:25.204557 #81782] DEBUG -- : update_register(21, 128, false)
D, [2020-01-15T10:53:25.204567 #81782] DEBUG -- : read_register(21)
D, [2020-01-15T10:53:26.135141 #81782] DEBUG -- : read_register 21 result = 62420
D, [2020-01-15T10:53:26.135204 #81782] DEBUG -- : set_register(21 62292)
```

If the inverter is already in the correct state, you'll see something like:

```
I, [2020-01-15T10:57:23.718003 #81969]  INFO -- : Current Octopus Unit Price: 8.2215p
D, [2020-01-15T10:57:23.718634 #81969] DEBUG -- : charge(false)
D, [2020-01-15T10:57:23.718658 #81969] DEBUG -- : update_register(21, 128, false)
D, [2020-01-15T10:57:23.718670 #81969] DEBUG -- : read_register(21)
D, [2020-01-15T10:57:24.829219 #81969] DEBUG -- : read_register 21 result = 62292
D, [2020-01-15T10:57:24.829271 #81969] DEBUG -- : register already has correct value, nothing to do
```

Occasionally the inverter fails to reply, this isn't really handled yet, but it does tell you about it:

```
I, [2020-01-15T10:57:11.762791 #81932]  INFO -- : Current Octopus Unit Price: 8.2215p
D, [2020-01-15T10:57:11.763346 #81932] DEBUG -- : charge(false)
D, [2020-01-15T10:57:11.763365 #81932] DEBUG -- : update_register(21, 128, false)
D, [2020-01-15T10:57:11.763377 #81932] DEBUG -- : read_register(21)
F, [2020-01-15T10:57:21.366535 #81932] FATAL -- : invalid/no reply from inverter
```

In this case, you should run it again and hopefully this time it works. In future I'll add some retry logic.

## TODO

### Retry logic if inverter fails to answer

Self-explanatory. If the inverter doesn't answer, we should probably close the socket and try again.

### Knowledge of state-of-charge so we can write rules based on it

This is non-trivial as we can't ask the inverter for it directly. It just sends it, at 2 minute intervals. So to get this we'll probably need to convert to being a service that runs constantly, and writes SOC to a tempfile that we can query.

Vague plan to make a HTTP service that talks to the inverter and runs permanently, then other one-off Ruby scripts to control it that can run from cron etc. Will just need to get the TCP comms bulletproof for this to work reliably.
