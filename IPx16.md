# IPx16 SIP Integration

This document describes the validated IPx16 configuration for the Riedel Lab
SIP Server.

For Asterisk installation, PJSIP configuration, NAT handling, and general
troubleshooting, see [README.md](README.md).

---

## 1. Validated Setup

The IPx16 was tested as extension `1003` against the Asterisk server running
on the company NUC.

    Artist G2 VoIP-108                 IPx16
    Extension 1002                     Extension 1003
    10.85.226.120                      10.85.226.46
            ↕                              ↕
            +-------- SIP + RTP -----------+
                         ↕
                      Asterisk
                    10.85.30.30

The IPx16 configuration was straightforward and required no device-specific
workarounds.

Validated:

- registration to Asterisk/PJSIP
- SIP Digest authentication
- incoming calls
- outgoing calls
- codec negotiation to G.711 μ-law (PCMU)
- bidirectional calling with Artist G2 VoIP-108

---

## 2. Asterisk Endpoint

The IPx16 uses extension:

    1003

A corresponding PJSIP endpoint and dialplan entry must exist on Asterisk.

Verify registration with:

    pjsip show endpoint 1003

A successful registration shows a contact similar to:

    sip:1003@10.85.226.46:5060

and Asterisk reports the endpoint as reachable.

---

## 3. SIP Server Configuration

In the IPx16 configuration software, a second SIP server was configured for
the lab Asterisk server.

Under:

    Operation Settings -> SIP Server

the validated settings are:

    Label:                 Asterisk
    SIP Server Interface:  LAN 1 : AES67 Primary
    SIP Server:            10.85.30.30
    Transport:             UDP
    Registration Timeout:  60 s

No backup SIP server or STUN server was required for this test.

---

## 4. SIP Line Configuration

Only Line 16 was configured for the lab Asterisk server.

Validated settings:

    Line:                   16
    Line Mode:              SIP
    SIP Server:             2: Asterisk
    User Name:              1003
    User Authentication:    1003
    Password:               <Asterisk password>
    Displayed Name:         1003
    DTMF Tx:                Inband
    Preferred Coding:       G.722
    Packet Size:            20 ms

The username, authentication username, and password must correspond to the
Asterisk endpoint configuration.

---

## 5. Codec Negotiation

The IPx16 test line was configured with G.722 as its preferred codec.

The current Asterisk endpoint allows:

    disallow=all
    allow=ulaw

During call setup, the IPx16 successfully negotiates G.711 μ-law (PCMU).

No codec-specific change was therefore required on the IPx16.

---

## 6. Artist G2 Interoperability

Bidirectional calling between the IPx16 and Artist G2 VoIP-108 has been
validated:

    IPx16 1003 <-> Asterisk <-> Artist G2 1002

For calls from the IPx16 to the Artist G2, the Artist VoIP line must accept
the incoming caller identity.

For the validated test:

    Phone No. incoming = 1003

This is an Artist G2 line-specific requirement rather than an IPx16 or
Asterisk requirement.

See [G2.md](G2.md) for details.

---

## 7. Known-Good Checklist

For a basic IPx16 connection:

1. Configure the Asterisk SIP server address.
2. Select UDP transport.
3. Assign the SIP line to the Asterisk server.
4. Configure the SIP username and authentication credentials.
5. Create the corresponding PJSIP endpoint on Asterisk.
6. Add the extension to the Asterisk dialplan.
7. Verify registration with `pjsip show endpoint 1003`.
8. Test calls in both directions.

No additional IPx16-specific configuration was required during the initial
interoperability test.

---

## 8. Validated Result

The IPx16 has been successfully integrated with the lab Asterisk server.

Validated path:

    IPx16 1003
         ↕
    Asterisk / PJSIP
         ↕
    Artist G2 VoIP-108 1002

The IPx16 registered and interoperated with Asterisk without requiring
device-specific SIP workarounds.
