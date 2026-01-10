package Wordwank::Schema::Result::Session;
use Moose;
use MooseX::NonMoose;
extends 'DBIx::Class::Core';

__PACKAGE__->table('sessions');
__PACKAGE__->load_components(qw/InflateColumn::DateTime TimeStamp/);
__PACKAGE__->add_columns(
    id => {
        data_type => 'text',
    },
    player_id => {
        data_type => 'uuid',
        is_foreign_key => 1,
    },
    expires_at => {
        data_type => 'timestamp with time zone',
    },
    created_at => {
        data_type => 'timestamp with time zone',
        set_on_create => 1,
    }
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    player => 'Wordwank::Schema::Result::Player',
    'player_id'
);

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
