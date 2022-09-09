# Cloudflare-DDNS Updater

## Usage
1. Setup records.txt to contain the records you want to update alongside the zoneID
```txt
example.com 1234567890
subdomain.example.com 1234567890
another.com 0987654321
```
2. Configure .env file with all the required variables (see .env.example)
3. Run the script using
```bash
./cloudflare.sh
```
4. Optional (Configure a cron job to run this automatically for you)

## Roadmap
- [x] Add support for multiple domains
- [X] Add support for multiple records per domain
- [ ] Add docker container for easy deployment on Windows machines running WSL2
- [ ] Add support for multiple cloudflare accounts
- [ ] Add support for multiple cloudflare tokens
- [ ] Add support for IPv6 records
## Thanks/Credits
- Jason K. ([@K0p1-Git](https://github.com/K0p1-Git)) for the original script this is based on which can be found [here](https://github.com/K0p1-Git/cloudflare-ddns-updater)
  (If you only need to upkeep a single record this script is great!)
- Co-pilot for helping me write this readme without actually having to think too hard
- Myself ([@GoByeBye](https://github.com/GoByeBye)) for being a lazy fuck, not wanting to update all my domains manually
- Telenor for refusing to give me a static IP thus forcing me to update my domains bi-weekly/monthly