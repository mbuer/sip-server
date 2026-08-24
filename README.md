# Riedel Lab SIP Server

> This is a Copilot-assisted project. 

A simple Asterisk-based SIP lab for interoperability testing of current Riedel
SIP interfaces and legacy Artist G2 VoIP hardware.

The project provides a reproducible environment for SIP registration, call
routing, codec negotiation, RTP testing, and troubleshooting.

Currently validated:

- Asterisk 20 / PJSIP
- MicroSIP
- Artist G2 VoIP-108
- IPx16 SIP Interface
- SIP over UDP
- SIP Digest authentication
- G.711 μ-law / PCMU
- Bidirectional RTP through Asterisk

Device-specific documentation:

- [Artist G2 VoIP-108](VoIP108G2.md)
- [IPx16 SIP Interface](IPx16.md)

---

## 1. Lab Topology

The current validated lab contains three SIP endpoints:

    MicroSIP 1001                    IPx16 1003
         ↕                               ↕
         +--------- SIP + RTP -----------+
                       ↕
                    Asterisk
                  Company NUC
                  10.85.30.30
                       ↕
                   SIP + RTP
                       ↕
              Artist G2 VoIP-108
                 Extension 1002
                 10.85.226.120

Asterisk acts as the SIP registrar and call router and intentionally remains
in the RTP media path.

Validated call paths:

    MicroSIP 1001 <-> Artist G2 1002
    MicroSIP 1001 <-> IPx16 1003
    IPx16 1003    <-> Artist G2 1002

MicroSIP provides a useful known-good reference endpoint when introducing or
troubleshooting Riedel hardware.

---

## 2. Installation and Initial Setup

For a new Debian/Ubuntu system, the included installation script performs the
basic setup:

    chmod +x install.sh
    ./install.sh

The script:

- installs Asterisk
- detects available IPv4 interfaces
- allows selection of the SIP interface
- updates the PJSIP bind address in `config/pjsip.conf`

The script deliberately stops there. Asterisk configuration is deployed and
validated manually using the steps below.

To verify the installation:

    asterisk -V
    sudo systemctl status asterisk --no-pager

The current NUC was validated with:

    Asterisk 20.6

---

## 3. PJSIP and chan_sip

This project uses **PJSIP only**.

Asterisk may also load the legacy `chan_sip` channel driver. During initial
deployment, `chan_sip` claimed UDP port 5060 before PJSIP could create its
transport.

The symptom was:

    pjsip show transports

returning:

    No objects found.

while:

    sip show settings

showed UDP/5060 in use.

This indicates that `chan_sip`, rather than PJSIP, owns the SIP port.

### Disable chan_sip

Edit:

    sudo nano /etc/asterisk/modules.conf

Under `[modules]`, add:

    noload => chan_sip.so

Restart Asterisk:

    sudo systemctl restart asterisk

Connect to the CLI:

    sudo asterisk -rvvv

Verify:

    module show like chan_sip
    pjsip show transports

`chan_sip` should no longer be loaded and PJSIP should show the configured
UDP transport.

---

## 4. Deploy the Configuration

Git-managed Asterisk configuration files are stored in:

    config/pjsip.conf
    config/extensions.conf

The active Asterisk configuration is located under:

    /etc/asterisk/

Deploy the repository configuration:

    sudo cp config/pjsip.conf /etc/asterisk/pjsip.conf
    sudo cp config/extensions.conf /etc/asterisk/extensions.conf

Restart Asterisk:

    sudo systemctl restart asterisk

Connect to the CLI:

    sudo asterisk -rvvv

Then verify:

    pjsip show transports
    pjsip show endpoints
    dialplan show internal

The current lab server uses:

    10.85.30.30:5060/UDP

The bind address is deployment-specific and must match the SIP interface
selected during installation.

---

## 5. SIP Endpoints

The current lab extensions are:

    1001 = MicroSIP
    1002 = Artist G2 VoIP-108
    1003 = IPx16 SIP Interface

The test endpoints currently use:

    disallow=all
    allow=ulaw

The endpoint configuration also contains:

    direct_media=no
    force_rport=yes
    rewrite_contact=yes
    rtp_symmetric=yes

Each SIP device requires:

- a PJSIP endpoint
- authentication
- an AOR
- a matching dialplan entry

Show all endpoints:

    pjsip show endpoints

Inspect a specific endpoint:

    pjsip show endpoint 1002

Registration and dialing are separate. A device can be successfully registered
but still cannot be called until its extension exists in the dialplan.

---

## 6. Media and NAT Handling

### RTP through Asterisk

The lab intentionally uses:

    direct_media=no

This keeps Asterisk in the media path:

    Endpoint A <-- RTP --> Asterisk <-- RTP --> Endpoint B

rather than allowing the endpoints to establish RTP directly.

Keeping Asterisk in the media path makes packet capture, codec analysis, and
interoperability troubleshooting considerably easier.

### NAT Handling

The endpoints also use:

    force_rport=yes
    rewrite_contact=yes
    rtp_symmetric=yes

These settings became important during MicroSIP testing.

MicroSIP advertised its local SIP address as:

    192.168.1.215:63696

while Asterisk actually received the traffic from:

    10.85.116.134:63696

Without NAT-aware handling, Asterisk could attempt to send SIP signaling back
to the advertised address rather than the address through which the client was
actually reachable.

#### rewrite_contact

    rewrite_contact=yes

Asterisk uses the source address from which the SIP registration was received
instead of relying only on the Contact address advertised by the client.

During testing, the resulting contact was similar to:

    sip:1001@10.85.116.134:63696;ob;
    x-ast-orig-host=192.168.1.215:63696

#### force_rport

    force_rport=yes

SIP responses are sent to the source IP address and UDP port from which the
request was actually received.

#### rtp_symmetric

    rtp_symmetric=yes

For RTP, Asterisk can send media toward the address and port from which RTP is
actually received instead of relying only on the address advertised in SDP.

Together with `direct_media=no`, these settings provide predictable SIP and
RTP behavior when NAT is involved.

---

## 7. Device Configuration

### MicroSIP

MicroSIP is used as the known-good reference endpoint.

Example configuration:

    SIP Server: 10.85.30.30
    Port:       5060
    Transport:  UDP
    Username:   1001
    Login:      1001
    Password:   <configured password>

A normal SIP Digest registration sequence is:

    REGISTER
        ↓
    401 Unauthorized
        ↓
    REGISTER + Authorization
        ↓
    200 OK

The initial `401 Unauthorized` is expected. It is the SIP Digest
authentication challenge and does not indicate a failed registration.

### Artist G2 VoIP-108

The Artist G2 VoIP-108 uses extension `1002`.

Its configuration has two distinct parts:

    Card / SIP Phone settings -> SIP registration
    VoIP Line settings        -> call behavior

An important finding is that `Phone No. incoming` must match the incoming
caller identity.

A mismatch can result in successful SIP call establishment followed
immediately by a BYE from the VoIP-108.

See [Artist G2 VoIP-108](VoIP108G2.md) for the validated configuration and
troubleshooting notes.

### IPx16 SIP Interface

The IPx16 uses extension `1003` and registers directly to the Asterisk PJSIP
server.

The test line was configured with G.722 as its preferred codec but
successfully negotiated G.711 μ-law / PCMU with the current Asterisk
configuration.

No IPx16-specific SIP workaround was required.

See [IPx16 SIP Interface](IPx16.md) for the validated configuration.

---

## 8. Dialplan

The current dialplan contains all three lab endpoints:

    [internal]

    exten => 1001,1,Dial(PJSIP/1001,30)
     same => n,Hangup()

    exten => 1002,1,Dial(PJSIP/1002,30)
     same => n,Hangup()

    exten => 1003,1,Dial(PJSIP/1003,30)
     same => n,Hangup()

New endpoints can be added using the same structure.

---

## 9. Troubleshooting

Connect to Asterisk:

    sudo asterisk -rvvv

Useful commands:

    pjsip show transports
    pjsip show endpoints
    pjsip show endpoint 1001
    dialplan show internal

### SIP Logging

Enable:

    pjsip set logger on

Disable:

    pjsip set logger off

### RTP Logging

Enable:

    rtp set debug on

Disable:

    rtp set debug off

During a working call, RTP packets should be visible in both directions.

### Packet Capture

Capture SIP signaling:

    sudo tcpdump -ni <interface> -A 'udp port 5060'

Capture traffic to or from a specific endpoint:

    sudo tcpdump -ni <interface> host <endpoint-ip>

A useful troubleshooting order is:

    Registration
         ↓
    SIP signaling
         ↓
    Endpoint configuration
         ↓
    SDP / codec negotiation
         ↓
    RTP / network

### Common Issues

#### PJSIP transport missing

If:

    pjsip show transports

returns:

    No objects found.

check whether `chan_sip` has claimed UDP/5060.

Verify that:

    noload => chan_sip.so

exists in:

    /etc/asterisk/modules.conf

#### Registration exceeds max contacts

If Asterisk reports:

    Registration attempt ... will exceed max contacts of 1

inspect the currently stored contact:

    pjsip show endpoint <extension>

A stale contact may still occupy the endpoint's single allowed registration.

#### Endpoint registers but cannot be called

Check the dialplan:

    dialplan show internal

The registered extension must also exist in `extensions.conf`.

#### Call establishes and immediately disconnects

If this occurs with the Artist G2 VoIP-108, check:

    Phone No. incoming

The value must match the calling extension.

See [Artist G2 VoIP-108](VoIP108G2.md) for details.

#### Call connects but there is no audio

Enable:

    rtp set debug on

Then verify:

- RTP in both directions
- SDP addresses
- codec negotiation
- routing
- firewall rules
- NAT handling

---

## 10. Git Workflow

Before starting work:

    git pull

Review local changes:

    git status
    git diff

After successfully testing a change:

    git add .
    git commit -m "Describe the tested change"
    git pull --rebase origin main
    git push

Only commit configuration changes after they have been tested.

Do not commit production or sensitive SIP credentials.

---

## 11. Project Status

The current lab has successfully validated:

    MicroSIP 1001
          ↕
       Asterisk
          ↕
    Artist G2 1002

    MicroSIP 1001
          ↕
       Asterisk
          ↕
       IPx16 1003

    IPx16 1003
          ↕
       Asterisk
          ↕
    Artist G2 1002

The lab now provides a known-good baseline for SIP interoperability testing
between current Riedel SIP interfaces and legacy Artist G2 VoIP hardware.
