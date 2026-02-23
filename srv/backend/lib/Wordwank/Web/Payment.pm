package Wordwank::Web::Payment;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::UserAgent;
use Mojo::Util qw(b64_encode);

sub create_checkout_session ($self) {
    my $api_key = $ENV{STRIPE_SECRET_KEY};
    
    my $ua = Mojo::UserAgent->new;
    my $res = $ua->post('https://api.stripe.com/v1/checkout/sessions' => {
        Authorization => 'Basic ' . b64_encode($api_key . ':', '')
    } => form => {
        success_url => $self->url_for('/')->to_abs . '?payment=success',
        cancel_url  => $self->url_for('/')->to_abs . '?payment=cancel',
        'payment_method_types[]' => 'card',
        'line_items[0][price_data][currency]' => 'usd',
        'line_items[0][price_data][product_data][name]' => 'Wordwank Donation',
        'line_items[0][price_data][unit_amount]' => 500, # $5.00
        'line_items[0][quantity]' => 1,
        mode => 'payment',
    })->result;

    if ($res->is_success) {
        my $data = $res->json;
        return $self->render(json => { url => $data->{url} });
    } else {
        $self->app->log->error("Stripe error: " . $res->message . " - " . $res->body);
        return $self->render(json => { error => "Payment initialization failed" }, status => 500);
    }
}

1;
