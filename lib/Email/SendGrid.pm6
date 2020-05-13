use Cro::HTTP::Client;
use Cro::Uri;

my constant API_BASE = Cro::Uri.parse('https://sendgrid.com/v3/');

#| A partial implementation of the SendGrid v3 API, sufficient for using it to do basic
#| email sending. Construct it with your API key (passed as the api-key parameter), and
#| optionally a from address to be used for all of the emails sent. Construct with
#| :persistent to use a persistent Cro HTTP client (can give better throughput if sending
#| many emails).
class Email::SendGrid {
    #| Minimal validation of an email address - simply that it has an @ sign.
    subset HasEmailSign of Str where .contains('@');

    #| Pairs together a name and email address, which are often needed together in the
    #| SendGrid API. A name is optional.
    class Address {
        has HasEmailSign $.email is required;
        has Str $.name;
        method for-json() {
            { :$!email, (:$!name if $!name) }
        }
    }

    #| Recipient lists may be an address or a list of addresses 1 to 1000 addresses.
    subset AddressOrListOfAddress where { !$^a.defined || $^a.all ~~ Address && 1 <= $^a.elems <= 1000 }

    #| Construct an Email::SendGrid::Address object from just an email address.
    multi sub address($email) is export {
        Address.new(:$email)
    }

    #| Construct an Email::SendGrid::Address object from an email address and a name.
    multi sub address($email, $name) is export {
        Address.new(:$email, :$name)
    }

    #| The SendGrid API key.
    has Str $.api-key is required;

    #| The default from address to use.
    has Address $.from;

    #| The Cro HTTP client used for communication.
    has Cro::HTTP::Client $.client;

    #| Send an email. The C<to>, C<cc>, and C<bcc> options may be a single Address object or
    #| a list of 1 to 1000 C<Address> objects. Only C<to> is required; C<from> is required if there
    #| is no object-level from address. Optionally, a C<reply-to> C<Address> may be provided.
    #| A C<subject> is required, as is a C<%content> hash that maps mime types into the matching
    #| bodies. If `async` is passed, the call to the API will take place asynchronously, and a
    #| C<Promise> returned.
    method send-mail(AddressOrListOfAddress :$to!, AddressOrListOfAddress :$cc,
            AddressOrListOfAddress :$bcc, Address :$from = $!from // die("Must specify a from address"),
            Address :$reply-to, Str :$subject!, :%content!, :$async, :$sandbox) {
        # Form the JSON payload describing the email.
        my %personalization = to => to-email-list($to);
        %personalization<cc> = to-email-list($_) with $cc;
        %personalization<bcc> = to-email-list($_) with $bcc;
        my %request-json =
                from => $from.for-json,
                personalizations => [%personalization,],
                :$subject,
                :content(form-content(%content));
        %request-json<reply-to> = .for-json with $reply-to;
        if $sandbox {
            %request-json<mail_settings><sandbox_mode><enable> = True;
        }

        # Make the HTTP request.
        my $req = $!client.post: API_BASE.add('mail/send'),
                auth => { bearer => $!api-key },
                content-type => 'application/json',
                body => %request-json;
        return $async ?? $req !! await($req);
    }

    multi sub to-email-list(Address $addr) {
        [$addr.for-json,]
    }

    multi sub to-email-list(@addresses) {
        [@addresses.map(*.for-json)]
    }

    sub form-content(%content is copy) {
        # Per API rules, text/plain must be first, then HTML, then anything else.
        my @formed;
        for 'text/plain', 'text/html' -> $type {
            with %content{$type}:delete -> $value {
                @formed.push: { :$type, :$value }
            }
        }
        for %content {
            @formed.push: %(type => .key, value => .value);
        }
        return @formed;
    }
}
