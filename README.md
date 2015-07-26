# grASA

Or gr(eppable) (Cisco)ASA converter. Grasa will parse Cisco ASA 9.1 config files and output in a "grep" friendly format.

Issues or updates can be found at: https://github.com/crcxx/grasa

## Disclaimer

Currently only supports ASA version 9.1 config format. Complaints, add additional versions yourself (or kindly request) :) 

## License

grasa is released under The MIT License, see LICENSE for more information.

## Requirements

Developed and tested with (MRI) ruby-2.1.6

* no requirements outside of stdlib

## Usage

Display help menu

	grasa.rb --help

List the available access-lists

    grasa.rb --file=ciscoasa.cfg
    
Convert ASA config to "greppable" format

    grasa.rb --file=ciscoasa.cfg --access-list=inside_access_in --dir=out
    
Lookup unknown network object

    grasa.rb --file=ciscoasa.cfg --network=corp_vlan_123

Lookup unknown network object-group

    grasa.rb --file=ciscoasa.cfg --network-group=corp_network
    
Lookup unknown service object

    grasa.rb --file=ciscoasa.cfg --service=bo2k

Lookup unknown service object-group

    grasa.rb --file=ciscoasa.cfg --service-group=ratz


