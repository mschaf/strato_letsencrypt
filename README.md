## Scripts to automatically add TXT records on domains hosted on Strato

Some scripts to automate the Let´s Encrypt DNS challenge for domains hosted on strato.  
By far not the best solution, this literally clicks through the strato website inside a headless browser to do this. But if your stuck with strato for some reason, this might be an option. If you can, use a dns provider with an API supported by Let´s Encrypt. An overview can be found here: https://community.letsencrypt.org/t/dns-providers-who-easily-integrate-with-lets-encrypt-dns-validation/86438

### Prerequisites

* A recent Ruby, tested with `2.7.3`
* Firefox
* Geckodriver for your version of Firefox (https://github.com/mozilla/geckodriver)
* Bundler, install with `gem install bundler`
* Gem dependencies, install with `bundler install`

### Getting Certificates

Example command for getting a certificate for `test.example.com`  
`STRATO_USERNAME=<username> STRATO_PASSWORD=<password> certbot --preferred-challenges dns --manual --manual-auth-hook ./auth_hook --manual-cleanup-hook ./cleanup_hook --agree-tos --manual-public-ip-logging-ok -d test.example.com certonly`  
The important part for these scripts is `--manual --manual-auth-hook ./auth_hook --manual-cleanup-hook ./cleanup_hook`

### Testing

There is a script testing all functionality of the scripts against a domain of your choice.  
`./test_strato_scripts <strator username> <strato password> <domain to test on>`

### Disclaimer

Theses scripts actually login into your strato account in a headless Firefox and click around to create subdomains, set TXT records and delete them again.
It worked for me at the time of writing, but might break at any time.  
If these scripts break something in your account, dont come here and blame me, run at your own risk.
