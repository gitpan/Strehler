package Strehler::Element::Log;

use Moo;
use Dancer2 0.11;
use Dancer2::Plugin::DBIC;
use DateTime::Format::Strptime;

extends 'Strehler::Element';

#Standard element implementation

sub metaclass_data 
{
    my $self = shift;
    my $param = shift;
    my %element_conf = ( item_type => 'log',
                         ORMObj => 'ActivityLog',
                         category_accessor => '',
                         multilang_children => '' );
    return $element_conf{$param};
}


sub write
{
    my $self = shift;
    my $user = shift;
    my $action = shift;
    my $entity_type = shift;
    my $entity_id = shift;
    my $log_row = $self->get_schema()->resultset($self->ORMObj())->create({ user => $user, action => $action, entity_type => $entity_type, entity_id => $entity_id, timestamp => DateTime->now() });
}

sub main_title
{
    my $self = shift;
    return "[" . $self->get_attr('timestamp') . "] " . $self->get_attr('action') . " " . $self->get_attr('entity_type');
}

=encoding utf8

=head1 NAME

Strehler::Element::Log - Strehler Entity for logs

=head1 DESCRIPTION

A little entity used to log Strehler backend actions and keep trace of it.

=cut

1;
