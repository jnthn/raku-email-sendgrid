use Cro::HTTP::Client;
use Email::SendGrid;
use Test;
use Test::Mock;

dies-ok { Email::SendGrid.new }, 'Cannot construct without an API key';
lives-ok { Email::SendGrid.new(api-key => 'abc') }, 'Can construct with an API key';

lives-ok { address('foo@bar.com') }, 'Can make an Address with an OK email address';
lives-ok { address('foo@bar.com', 'Mr Foo') }, 'Can make an Address with an OK email address and name';
dies-ok { address('Mr Foo', 'foo@bar.com') }, 'Simple heuristic catches swapping name and email';

{
    my $mock-client = mocked(Cro::HTTP::Client, returning => { post => Promise.kept });
    given Email::SendGrid.new(api-key => 'abc', client => $mock-client, from => address('foo@bar.com')) {
        dies-ok { .send-mail(to => [], subject => 'Foo', content => { 'text/plain' => 'Hello!' }) },
                'Empty to list is not allowed';
        check-mock $mock-client,
                *.never-called('post');

        dies-ok { .send-mail(to => [address('foo@bar.com') xx 1001], subject => 'Foo', content => { 'text/plain' => 'Hello!' }) },
                'Too long to list is not allowed';
        check-mock $mock-client,
                *.never-called('post');

        lives-ok { .send-mail(to => address('foo@bar.com'), subject => 'Foo', content => { 'text/plain' => 'Hello!' }) },
                'Can send with required arguments provided';
        check-mock $mock-client,
                *.called('post', times => 1);
    }
}

{
    my %result;
    my $mock-client = mocked(Cro::HTTP::Client, overriding => {
        post => -> $, :%body, *% { %result := %body; Promise.kept }
    });
    given Email::SendGrid.new(api-key => 'abc', client => $mock-client, from => address('foo@bar.com')) {
        .send-mail(to => address('foo@bar.com'), subject => 'Foo', content => { 'text/plain' => 'Hello!' }, :sandbox);
      is True, %result<mail_settings><sandbox_mode><enable>;
    }
}

done-testing;
