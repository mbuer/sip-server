# Riedel Lab SIP Server

Asterisk-based SIP server for lab testing and interoperability testing of SIP audio devices.

The primary purpose of this server is to test SIP communication between current Riedel SIP interfaces and legacy Artist G2 VoIP hardware.

## Lab Purpose

Planned hardware includes:

- IPx16 SIP Interface
- Duo SIP Interface
- Artist G2 VoIP-108 Client Card

The SIP server acts as the intermediary between the SIP endpoints:

    IPx16 / Duo
         |
         | SIP + RTP
         |
      Asterisk
         |
         | SIP + RTP
         |
    Artist G2
    VoIP-108

MicroSIP clients can be used as diagnostic endpoints to validate the
Asterisk configuration independently of the hardware under test.

This allows us to establish a known-good SIP baseline before troubleshooting
hardware interoperability.

## Server

- Platform: Linux
- SIP Server: Asterisk 20
- SIP Configuration: PJSIP
- SIP Transport: UDP
- SIP Port: 5060
- Initial test codec: G.711 μ-law (PCMU)

> Update the server IP information when deploying the repository to a
> different machine or network.

## SIP Client Configuration

A SIP endpoint requires:

    SIP Server: <NUC-IP>
    Port:       5060
    Transport:  UDP

Each endpoint requires its own SIP extension and credentials.

Example:

    Extension: 1001
    Username:  1001
    Password:  <configured password>

## Media Handling

Asterisk is intentionally configured with:

    direct_media=no

This keeps RTP in the Asterisk media path instead of allowing the two
endpoints to establish a direct RTP connection.

Conceptually:

    Endpoint A
        |
        | RTP
        v
     Asterisk
        |
        | RTP
        v
    Endpoint B

This is useful for:

- SIP interoperability testing
- RTP troubleshooting
- Packet captures
- Codec analysis
- Legacy device integration
- Future media proxy/testing applications

## Current Validation

The initial server configuration was validated using two MicroSIP clients.

The following functionality has been confirmed:

- SIP endpoint registration
- SIP Digest authentication
- Calls between two registered endpoints
- G.711 μ-law (PCMU) negotiation
- Bidirectional RTP
- RTP passing through the Asterisk media path

MicroSIP therefore provides a known-good reference endpoint when
troubleshooting the IPx16, Duo, or Artist G2 VoIP-108.

## Asterisk CLI

Connect to the running Asterisk instance:

    sudo asterisk -rvvv

Show configured endpoints:

    pjsip show endpoints

Show a specific endpoint:

    pjsip show endpoint 1001

Show the lab dialplan:

    dialplan show internal

Exit the Asterisk CLI:

    exit

## RTP Troubleshooting

From the Asterisk CLI, enable RTP debugging:

    rtp set debug on

During a working call, RTP packets should be visible in both directions.

Disable RTP debugging when finished:

    rtp set debug off

RTP debugging can generate a large amount of output and should normally
remain disabled when it is not required.

## SIP Packet Capture

SIP signaling can also be inspected directly from Linux.

Example:

    sudo tcpdump -ni <interface> -A 'udp port 5060'

A normal SIP registration using Digest authentication should show:

    REGISTER
        |
        v
    401 Unauthorized
        |
        v
    REGISTER + Digest authentication
        |
        v
    200 OK

The initial `401 Unauthorized` response is expected. It is the SIP Digest
authentication challenge and does not indicate a failed registration.

## Configuration Files

Git-managed Asterisk configuration files are stored in:

    config/pjsip.conf
    config/extensions.conf

The active Asterisk configuration is located under:

    /etc/asterisk/

After changing the repository configuration, deploy the files:

    sudo cp config/pjsip.conf /etc/asterisk/pjsip.conf
    sudo cp config/extensions.conf /etc/asterisk/extensions.conf

Restart Asterisk:

    sudo systemctl restart asterisk

Check its status:

    sudo systemctl status asterisk --no-pager

Then verify the configuration:

    sudo asterisk -rvvv

Inside the Asterisk CLI:

    pjsip show endpoints
    dialplan show internal

## Git Workflow

Before starting work:

    git pull

Check local changes:

    git status

After successfully testing a configuration change:

    git add .
    git commit -m "Describe the change"
    git push

Only commit configuration changes after they have been tested.

## Credentials

Do not commit production or sensitive SIP credentials to GitHub.

Repository configurations should use lab credentials or placeholders where
possible. Deployment-specific credentials should be managed separately.

## Planned Hardware Testing

The next phase is interoperability testing with actual Riedel hardware.

Suggested progression:

    MicroSIP <-> Asterisk <-> MicroSIP
                    |
                 VERIFIED

    IPx16/Duo <-> Asterisk <-> MicroSIP

    MicroSIP <-> Asterisk <-> Artist G2 VoIP-108

    IPx16/Duo <-> Asterisk <-> Artist G2 VoIP-108

Using a known-good MicroSIP endpoint on one side makes it easier to isolate
registration, signaling, SDP, codec, and RTP problems before testing the
complete hardware-to-hardware path.

## Project Status

Current status:

    Asterisk installed and running
    PJSIP configured
    Two test extensions configured
    MicroSIP registration verified
    SIP calls verified
    PCMU audio verified
    Bidirectional RTP verified
    direct_media=no enabled

Next milestone:

    Test registration and calling with IPx16 / Duo and Artist G2 VoIP-108.
