# Email::SendGrid

A basic Raku module for sending email using the [SendGrid Web API (v3)](https://sendgrid.com/docs/API_Reference/api_v3.html).
At the time of writing, SendGrid allows sending up to 100 emails a day free
of charge. This module most certainly does not provide full coverage of the
SendGrid API; if you need more, pull requests are welcome.

## Usage

Construct an `Eamil::SendGrid` object using your SendGrid API key:

```
my $sendgrid = Email::SendGrid.new(api-key => 'your_key_here');
```

Then call `send-mail` to send email:

```
$sendgrid.send-mail:
        from => address('some@address.com', 'Sender name'),
        to => address('target@address.com', 'Recipient name'),
        subject => 'Yay, SendGrid works!',
        content => {
            'text/plain' => 'This is the plain text message',
            'text/html' => '<strong>HTML mail!</strong>'
        };
```

It is not required to including a HTML version of the body. Optionally, pass
`cc`, `bcc`, and `reply-to` to send these addresses. It is also possible to
pass a list of up to 1000 addresses to `to`, `cc`, and `bcc`. 

If sending the mail fails, an exception will be thrown. Since `Cro::HTTP::Client`
is used internally, it will be an exception from that. Study the body for more
details.

```
CATCH {
    default {
        note await .response.body;
    }
}
``` 

Pass `:async` to `send-mail` to get a `Promise` back instead. Otherwise, it will
be `await`ed for you by `send-mail`.
