package Strehler::Meta::Tag;

use Moo;
use Dancer2 0.11;
use Dancer2::Plugin::DBIC;
use Data::Dumper;

has row => (
    is => 'ro',
);

sub BUILDARGS {
   my ( $class, @args ) = @_;
   my $tag = undef;
   if($#args == 0)
   {
        my $id = shift @args; 
        $tag = $class->get_schema()->resultset('Tag')->find($id);
   }
   elsif($#args == 1)
   {
       if($args[0] eq 'tag')
       {
            $tag = $class->get_schema()->resultset('Tag')->find({ tag => $args[1] });
       }
       if($args[0] eq 'row')
       {
            $tag = $args[1];
       }
   }
   return { row => $tag };
};
sub get_schema
{
    if(config->{'Strehler'}->{'schema'})
    {
        return schema config->{'Strehler'}->{'schema'};
    }
    else
    {
        return schema;
    }
}


sub tags_to_string
{
    my $self = shift;
    my $item = shift;
    my $item_type = shift;
    my @tags = $self->get_schema()->resultset('Tag')->search({ item_id => $item, item_type => $item_type });
    my $out = "";
    for(@tags)
    {
        $out .= $_->tag . ",";
    }
    $out =~ s/,$//;
    return $out;
}

sub get_elements_by_tag
{
    my $self = shift;
    my $tag = shift;
    my @images;
    my @articles;
    foreach($self->get_schema()->resultset('Tag')->search({tag => $tag, item_type => 'image'}))
    {
        push @images, Strehler::Element::Image->new($_->item_id);
    }
    for($self->get_schema()->resultset('Tag')->search({tag => $tag, item_type => 'article'}))
    {
        push @articles, Strehler::Element::Article->new($_->item_id);
    }
    return { images => \@images, articles => \@articles };
}

sub save_tags
{
    my $self = shift;
    my $string = shift;
    my $item = shift;
    my $item_type = shift;
    $string ||= '';
    $string =~ s/( +)?,( +)?/,/g;
    my @tags = split(',', $string);
    $self->get_schema()->resultset('Tag')->search({item_id => $item, item_type => $item_type})->delete_all();
    my %already;
    for(@tags)
    {
        if(! $already{$_})
        {
            $already{$_} = 1;
            my $new_tag = $self->get_schema()->resultset('Tag')->create({tag => $_, item_id => $item, item_type => $item_type});
        }
    }
}

sub get_configured_tags
{
    my $self = shift;
    my $category = shift;
    my $t = shift;
    my @types = @{$t};
    my $out;
    foreach my $t (@types)
    {
        my @tags = $self->get_schema()->resultset('ConfiguredTag')->search({category_id => $category, item_type => $t});
        my $string = '';
        my $default = '';
        for(@tags)
        {
            $string .= $_->tag;
            $string .= ",";
            if($_->default_tag == 1)
            {
                $default .= $_->tag;
                $default .= ",";
            }
        }
        $string =~ s/,$//;
        $default =~ s/,$//;
        if($string ne '')
        {
            $out->{$t} = $string;
        }
        else
        {
            $out->{$t} = undef;
        }
        $out->{'default-' . $t} = $default;
    }
    return $out;
}
sub get_configured_tags_for_template
{
    my $self = shift;
    my $category = shift;
    my $type = shift;
    my @tags = $self->get_schema()->resultset('ConfiguredTag')->search({category_id => $category, item_type => 'all'});
    if($#tags > -1)
    {
        return @tags;
    }
    else
    {
        @tags = $self->get_schema()->resultset('ConfiguredTag')->search({category_id => $category, item_type => $type});
        return @tags;
    }
}

sub save_configured_tags
{
    my $self = shift;
    my $string = shift;
    my $default_tags = shift;
    my $category = shift;
    my $type = shift;
    $default_tags ||= '';
    $string =~ s/( +)?,( +)?/,/g;
    $default_tags =~ s/( +)?,( +)?/,/g;
    my @tags = split(',', $string);
    my @dtags = split(',', $default_tags);
    my %already;
    foreach my $t (@tags)
    {
        if(! $already{$t})
        {
            $already{$t} = 1;
            my $default = 0;
            if (grep {$_ eq $t} @dtags) {
                $default = 1;
            }
            $self->get_schema()->resultset('ConfiguredTag')->create({tag => $t, category_id => $category, item_type => $type, default_tag => $default});
        }
    }
}

sub clean_configured_tags
{
    my $self = shift;
    my $category = shift;
    $self->get_schema()->resultset('ConfiguredTag')->search({ category_id => $category })->delete_all();
}



1;







