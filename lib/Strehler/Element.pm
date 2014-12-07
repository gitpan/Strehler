package Strehler::Element;
$Strehler::Element::VERSION = '1.4.1';
use strict;
use Moo;
use Dancer2 0.154000;
use Dancer2::Plugin::DBIC;
use Strehler::Meta::Tag;
use Strehler::Meta::Category;
use Strehler::Helpers;

with 'Strehler::Element::Role::Configured';

has row => (
    is => 'ro',
);

sub BUILDARGS {
   my ( $class, @args ) = @_;
   my $id = shift @args; 
   my $article;
   if(! $id)
   {
        $article = undef;
   }
   else
   {
        $article = $class->get_schema()->resultset($class->ORMObj())->find($id);
   }
   return { row => $article };
};

sub metaclass_data 
{
    my $self = shift;
    my $param = shift;
    my %element_conf = ( item_type => 'element',
                         ORMObj => undef,
                         category_accessor => undef,
                         multilang_children => undef );
    return $element_conf{$param};
}

sub exists
{
    my $self = shift;
    if($self->row)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}
sub delete
{
    my $self = shift;
    my $children = $self->row->can($self->multilang_children());
    $self->row->$children->delete_all() if($children);
    $self->row->delete();
}

sub get_attr
{
    my $self = shift;
    my $attribute = shift;
    my $bare = shift || 0;
    my $accessor = $self->can($attribute);
    if($accessor && ! $bare)
    {
        if($self->row->result_source->has_column($attribute))
        {
            return $self->$accessor($self->row->$attribute);
        }
        else
        {
            return $self->$accessor(undef);
        }
    }
    if($attribute eq 'category')
    {
        return $self->row->category->category;
    }
    if($attribute eq 'main-title')
    {
        return $self->main_title();
    }
    if($attribute eq 'category-name')
    {
        return $self->get_category_name();
    }
    else
    {
        if($self->row->result_source->has_column($attribute))
        {
            if($self->row->result_source->column_info($attribute)->{'data_type'} eq 'timestamp' || $self->row->result_source->column_info($attribute)->{'data_type'} eq 'datetime')
            {
                my $ts = $self->row->$attribute;
                if($ts)
                {
                    $ts->set_time_zone('UTC');
                    $ts->set_time_zone(config->{'Strehler'}->{'timezone'});
                    return $ts;
                }
                else
                {
                    return undef;
                }
            }
            elsif($self->row->result_source->column_info($attribute)->{'data_type'} eq 'date')
            {
                return $self->row->$attribute;
            }
            else
            {
                return $self->row->get_column($attribute);
            }
        }
        else
        {
            return undef;
        }
    }
}
sub get_attr_multilang
{
    my $self = shift;
    my $attribute = shift;
    my $lang = shift;
    my $bare = shift;
    my $accessor = $self->can($attribute);
    my $children = $self->row->can($self->multilang_children());
    return undef if not $children;
    my $content = $self->row->$children->find({'language' => $lang});
    my $content_attribute = undef;
    if($content && $content->result_source->has_column($attribute))
    {
        $content_attribute = $content->$attribute;
    }
    if($accessor && ! $bare)
    {
        return $self->$accessor($content_attribute, $lang);
    }
    if($content)
    {
        if($content->result_source->has_column($attribute))
        {
            if($content->result_source->column_info($attribute)->{'data_type'} eq 'timestamp' || $content->result_source->column_info($attribute)->{'data_type'} eq 'datetime')
            {
                my $ts = $content->$attribute;
                if($ts)
                {
                    $ts->set_time_zone('UTC');
                    $ts->set_time_zone(config->{'Strehler'}->{'timezone'});
                    return $ts;
                }
                else
                {
                    return undef;
                }
            }
            elsif($content->result_source->column_info($attribute)->{'data_type'} eq 'date')
            {
                return $content->$attribute;
            }
            else
            {
                return $content->get_column($attribute);
            }
        }
        else
        {
            return undef;
        }
    }
    else
    {
        return undef;
    }
}
sub has_language
{
    my $self = shift;
    my $language = shift;
    my $children = $self->row->can($self->multilang_children());
    return 1 if not $children;
    my $content = $self->row->$children->find({language => $language});
    if($content)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}
sub get_tags
{
    my $self = shift;
    my $tags = Strehler::Meta::Tag->tags_to_string($self->get_attr('id'), $self->item_type());
    return $tags;
}
sub get_category_name
{
    my $self = shift;
    if($self->row->can('category'))
    {
            my $category = Strehler::Meta::Category->new($self->row->category->id);
            return $category->ext_name();
    }
    else
    {
        return undef;
    }
}
sub get_category_id
{
    my $self = shift;
    if($self->row->can('category'))
    {
            return $self->row->category->id;
    }
    else
    {
        return undef;
    }
}
sub max_category_order
{
    my $self = shift;
    my $category_id = shift;
    my $max;
    if($category_id)
    {
        my $category = Strehler::Meta::Category->new($category_id);
        my $category_accessor = $self->category_accessor($category->row);
        $max = $category->row->$category_accessor->search()->get_column('display_order')->max();
    }
    else
    {
        $max = $self->get_schema()->resultset($self->ORMObj())->search()->get_column('display_order')->max();
    }
    return $max || 0;
}

sub get_data_fields
{
    my $self = shift;
    if($self->data_fields())
    {
        return $self->data_fields();
    }
    else
    {
        return $self->row->result_source->columns;
    }
}

sub get_multilang_data_fields
{
    my $self = shift;
    my $children = shift;
    if($self->multilang_data_fields())
    {
        return $self->multilang_data_fields();
    }
    else
    {
        return $self->row->$children->result_source->columns
    }
}



sub get_basic_data
{
    my $self = shift;
    my %data;
    foreach my $c ($self->get_data_fields())
    {
        $data{$c} = $self->get_attr($c);
    }
    $data{'title'} = $self->main_title;
    $data{'category_name'} = $self->get_category_name();
    return %data;
}
sub get_ext_data
{
    my $self = shift;
    my $language = shift;
    my %data;
    %data = $self->get_basic_data();
    my $children = $self->row->can($self->multilang_children());
    if($children)
    {
        foreach my $c ($self->get_multilang_data_fields($children))
        {
            if($c ne 'id' && $c ne $self->item_type() && $c ne 'language')
            {
                $data{$c} = $self->get_attr_multilang($c, $language);
            }
        }
    }
    return %data;
}

sub get_json_data
{
    my $self = shift;
    my $language = shift;
    my %data = $self->get_ext_data($language);
    foreach my $key (keys %data)
    {
        if(ref $data{$key} eq 'DateTime')
        {
            $data{$key} = $data{$key}->epoch();
        }
    }
    return %data;
}

sub main_title
{
    my $self = shift;
    if($self->get_attr('title'))
    {
        return $self->get_attr('title');
    }
    elsif($self->get_attr('name'))
    {
        return $self->get_attr('name');
    }   
    else
    {
        return "[". $self->get_attr('id') . "]";
    }
}
sub fields_list
{
    my $self = shift;
    my $item = $self->metaclass_data('item_type');
    my $class = Strehler::Helpers::class_from_entity($item);
    my %attributes = $class->entity_data();
    my $resultset = $self->get_schema()->resultset($self->ORMObj());
    my $title_id = $self->default_field();
    my $title_label = $title_id ? ucfirst($title_id) : 'Title';
    my $title_ordinable = $title_id ? 1 : 0;
    my @fields = ( { 'id' => 'id',
                     'label' => 'ID',
                     'ordinable' => 1 },
                   { 'id' => $title_id,
                     'label' => $title_label,
                     'ordinable' => $title_ordinable } );
    if($attributes{'categorized'})
    {
        push @fields, { 'id' => 'category',
                       'label' => 'Category',
                       'ordinable' => 0 };
    }
    if($attributes{'ordered'})
    {
        push @fields, { 'id' => 'display_order',
                       'label' => 'Order',
                       'ordinable' => 1 };
    }
    if($attributes{'dated'})
    {
        push @fields, { 'id' => 'publish_date',
                       'label' => 'Date',
                       'ordinable' => 1 };
    }
    if($attributes{'publishable'})
    {
        push @fields, { 'id' => 'published',
                       'label' => 'Status',
                       'ordinable' => 1 };
    }
    return \@fields;
    
}
sub default_field
{
    my $self = shift;
    my $resultset = $self->get_schema()->resultset($self->ORMObj());
    if($resultset->result_source->has_column('title'))
    {
        return 'title';
    }
    elsif($resultset->result_source->has_column('name'))
    {
        return 'name';
    }
    else
    {
        return undef;
    }

}
sub publish
{
    my $self = shift;
    return if ! $self->publishable();
    $self->row->published(1);
    $self->row->update();
}
sub unpublish
{
    my $self = shift;
    return if ! $self->publishable();
    $self->row->published(0);
    $self->row->update();
}
sub next_in_category_by_order
{
    my $self = shift;
    my $language = shift;
    my $category = $self->get_schema()->resultset('Category')->find($self->get_category_id());
    my $category_access = $self->category_accessor($category);
    my $my_order = $self->get_attr('display_order') || 0;
    my $criteria = { display_order => { '>',  $my_order}};
    if($self->publishable())
    {
        $criteria->{'published'} = 1;
    }
 
    my @nexts = $category->$category_access->search($criteria, { order_by => {-asc => 'display_order' }});
    if($#nexts >= 0)
    {
        for(@nexts)
        {
            my $el = $self->new($_->id);
            if($el->has_language($language))
            {
                return $el;
            }
        }
    }
    return $self->new(undef);
}
sub prev_in_category_by_order
{
    my $self = shift;
    my $language = shift;
    my $category = $self->get_schema()->resultset('Category')->find($self->get_category_id());
    my $category_access = $self->category_accessor($category);
    my $my_order = $self->get_attr('display_order') || 0;
    my $criteria = { display_order => { '<', $my_order }};
    if($self->publishable())
    {
        $criteria->{'published'} = 1;
    }
    my @nexts = $category->$category_access->search($criteria, { order_by => {-desc => 'display_order' }});
    if($#nexts >= 0)
    {
        for(@nexts)
        {
            my $el = $self->new($_->id);
            if($el->has_language($language))
            {
                return $el;
            }
        }
    }
    return $self->new(undef);
}
sub next_in_category_by_date
{
    my $self = shift;
    my $language = shift;
    my $category = $self->get_schema()->resultset('Category')->find($self->get_category_id());
    my $my_date = $self->get_attr('publish_date') || DateTime->from_epoch( epoch => 0);
    my $category_access = $self->category_accessor($category);
    my $criteria = {publish_date => { '>', $my_date }};
    if($self->publishable())
    {
        $criteria->{'published'} = 1;
    }
    my @nexts = $category->$category_access->search($criteria, { order_by => {-asc => 'publish_date' }});
    if($#nexts >= 0)
    {
        for(@nexts)
        {
            my $el = $self->new($_->id);
            if($el->has_language($language))
            {
                return $el;
            }
        }
    }
    return $self->new(undef);
}
sub prev_in_category_by_date
{
    my $self = shift;
    my $language = shift;
    my $category = $self->get_schema()->resultset('Category')->find($self->get_category_id());
    my $category_access = $self->category_accessor($category);
    my $my_date = $self->get_attr('publish_date') || DateTime->from_epoch( epoch => 0);
    my $criteria = { publish_date => { '<', $my_date }};
    if($self->publishable())
    {
        $criteria->{'published'} = 1;
    }
    my @nexts = $category->$category_access->search($criteria , { order_by => {-desc => 'publish_date' }});
    if($#nexts >= 0)
    {
        for(@nexts)
        {
            my $el = $self->new($_->id);
            if($el->has_language($language))
            {
                return $el;
            }
        }
    }
    return $self->new(undef);
}
sub get_last_by_order
{
    my $self = shift;
    my $cat = shift;
    my $language = shift;
    my $category = Strehler::Meta::Category->explode_name($cat);
    return undef if(! $category->exists());
    my $category_access = $self->category_accessor($category->row);
    my $criteria = {};
    if($self->publishable())
    {
        $criteria = { published => 1 };
    }
    my @chapters = $category->row->$category_access->search($criteria , { order_by => { -desc => 'display_order' } });
    if($chapters[0])
    {
        for(@chapters)
        {
            my $el = $self->new($_->id);
            if($el->has_language($language))
            {
                return $el;
            }
        }
    }
    return undef;
}
sub get_last_by_date
{
    my $self = shift;
    my $cat = shift;
    my $language = shift;
    my $category = Strehler::Meta::Category->explode_name($cat);
    return undef if(! $category->exists());
    my $category_access = $self->category_accessor($category->row);
    my $criteria = {};
    if($self->publishable())
    {
        $criteria = { published => 1 };
    }
    my @chapters = $category->row->$category_access->search( $criteria, { order_by => { -desc => 'publish_date' } });
    if($chapters[0])
    {
        for(@chapters)
        {
            my $el = $self->new($_->id);
            if($el->has_language($language))
            {
                return $el;
            }
        }
    }
    return undef;
}
sub get_first_by_order
{
    my $self = shift;
    my $cat = shift;
    my $language = shift;
    my $category = Strehler::Meta::Category->explode_name($cat);
    return undef if(! $category->exists());
    my $category_access = $self->category_accessor($category->row);
    my $criteria = {};
    if($self->publishable())
    {
        $criteria = { published => 1 };
    }
    my @chapters = $category->row->$category_access->search( $criteria, { order_by => { -asc => 'display_order' } });
    if($chapters[0])
    {
        for(@chapters)
        {
            my $el = $self->new($_->id);
            if($el->has_language($language))
            {
                return $el;
            }
        }
    }
    return undef;
}
sub get_first_by_date
{
    my $self = shift;
    my $cat = shift;
    my $language = shift;
    my $category = Strehler::Meta::Category->explode_name($cat);
    return undef if(! $category->exists());
    my $category_access = $self->category_accessor($category->row);
    my $criteria = {};
    if($self->publishable())
    {
        $criteria = { published => 1 };
    }
    my @chapters = $category->row->$category_access->search( $criteria, { order_by => { -asc => 'publish_date' } });
    if($chapters[0])
    {
        for(@chapters)
        {
            my $el = $self->new($_->id);
            if($el->has_language($language))
            {
                return $el;
            }
        }
    }
    return undef;
}

sub get_list
{
    my $self = shift;
    my $params = shift;
    my %args;
    if($params)
    {
        %args = %{ $params };
    }
    else
    {
        %args = ();
    }

    $args{'order'} ||= 'desc';
    $args{'order_by'} ||= 'id';
    $args{'entries_per_page'} ||= 20;
    $args{'page'} ||= 1;
    $args{'language'} ||= config->{Strehler}->{default_language};
    $args{'join'} ||= [];
    $args{'join'} = [ $args{'join'} ] if(! ref($args{'join'}));
    my $no_paging = 0;
    my $default_page = 1;
    my $search_criteria = $args{'search'} || undef;

    if($args{'order_by'} =~ /^(.*?)\.(.*?)$/)
    {
        my $order_join = $1;
        push @{$args{'join'}}, $order_join;
    }
    my %seen = ();
    my @joins = grep { ! $seen{ $_ }++ } @{$args{'join'}};
    $args{'join'} = \@joins;
    if($args{'entries_per_page'} == -1)
    {
        $args{'entries_per_page'} = undef;
        $default_page = undef;
        $no_paging = 1;
    }

    if($self->publishable())
    {
        if(exists $args{'published'})
        {
            $search_criteria->{'published'} = $args{'published'};
        }
    }
    if(exists $args{'tag'} && $args{'tag'})
    {
        my $ids = $self->get_schema()->resultset('Tag')->search({tag => $args{'tag'}, item_type => $self->item_type()})->get_column('item_id');
        $search_criteria->{'id'} = { -in => $ids->as_query };
    }
    my $search_rules = { order_by => { '-' . $args{'order'} => $args{'order_by'} } , page => $default_page, rows => $args{'entries_per_page'}, join => $args{'join'}, distinct => 1 };

    my $rs;
    if(exists $args{'category_id'} && $args{'category_id'})
    {
        my $category = $self->get_schema()->resultset('Category')->find( { id => $args{'category_id'} } );
        if(! $category)
        {
            return {'to_view' => [], 'last_page' => 1 };
        }
        my $category_access = $self->category_accessor($category);
        $rs = $category->$category_access->search($search_criteria, $search_rules);
    }
    elsif(exists $args{'category'} && $args{'category'})
    {
        my $category;
        my $category_obj = Strehler::Meta::Category->explode_name($args{'category'});
        if(! $category_obj->exists())
        {
            return {'to_view' => [], 'last_page' => 1 };
        }
        else
        {
            $category = $category_obj->row;
        }
        my $category_access = $self->category_accessor($category);
        $rs = $category->$category_access->search($search_criteria, $search_rules);
    }
    elsif(exists $args{'ancestor'} && $args{'ancestor'})
    {
        my $category_obj = Strehler::Meta::Category->new($args{'ancestor'});
        my @category_ids;
        push @category_ids, $args{'ancestor'};
        my @subcategories = $category_obj->subcategories;
        for(@subcategories)
        {
            push @category_ids, $_->get_attr('id');
        }
        $search_criteria->{'category'} = { -in => \@category_ids };
        $rs = $self->get_schema()->resultset($self->ORMObj())->search($search_criteria, $search_rules);
    }
    else
    {
        $rs = $self->get_schema()->resultset($self->ORMObj())->search($search_criteria, $search_rules);
    }
 
    my $elements;
    my $last_page;
    if($no_paging)
    {
        $elements = $rs;
        $last_page = 1;
    }
    else
    {
        my $pager = $rs->pager();
        $elements = $rs->page($args{'page'});
        $last_page = $pager->last_page();
    }
    my @to_view;
    for($elements->all())
    {
        my $img = $self->new($_->id);
        my %el;
        if(exists $args{'json'})
        {
            %el = $img->get_json_data($args{'language'});
        }
        else
        {
            if(exists $args{'ext'})
            {
                %el = $img->get_ext_data($args{'language'});
            }
            else
            {
                %el = $img->get_basic_data();
            }
        }
        push @to_view, \%el;
    }
    return {'to_view' => \@to_view, 'last_page' => $last_page};
}

sub search_box
{
    my $self = shift;
    my $string = shift;
    my $parameters = shift;
    $parameters->{'search'} = { $self->default_field() => { 'like', "%$string%" } };
    return $self->get_list($parameters);
}

sub make_select
{
    my $self = shift;
    my $list = $self->get_list( { entries_per_page => -1 } );
    my @category_values_for_select;
    push @category_values_for_select, { value => undef, label => "-- seleziona --" }; 
    my @elements = @{$list->{to_view}};
    @elements = sort { lc($a->{'title'}) cmp lc($b->{'title'}) } @elements;
    for(@elements)
    {
        push @category_values_for_select, { value => $_->{'id'}, label => $_->{'title'} }
    }
    return \@category_values_for_select;
}

sub get_form_data
{
    my $self = shift;
    my $el_row = $self->row;
    my %columns = $el_row->get_columns;
    my $data = \%columns;
    foreach my $attribute (keys %columns)
    {
        if($el_row->result_source->column_info($attribute)->{'data_type'} eq 'timestamp' || $el_row->result_source->column_info($attribute)->{'data_type'} eq 'date' || $el_row->result_source->column_info($attribute)->{'data_type'} eq 'datetime')
        {
            $data->{$attribute} = $el_row->$attribute;
        }
    }
    if($self->categorized()) #Is the element categorized?
    {
        if($el_row->category->parent)
        {
            $data->{'category'} = $el_row->category->parent->id;
            $data->{'subcategory'} = $el_row->category->id;
        }
        else
        {
            $data->{'category'} = $el_row->category->id;
        }
    }
    $data->{'tags'} = $self->get_tags();
    my $children = $self->row->can($self->multilang_children());
    if($children)
    {
        my @multilang_rows = $self->row->$children;
        foreach my $ml (@multilang_rows)
        {
            my %ml_columns = $ml->get_columns;
            foreach my $k (keys %ml_columns)
            {
                if($k ne 'id' && $k ne $self->item_type() && $k ne 'language')
                {
                    foreach my $attribute (keys %columns)
                    {
                        my $data_to_save;
                        if($ml->result_source->column_info($k)->{'data_type'} eq 'timestamp' || $ml->result_source->column_info($k)->{'data_type'} eq 'date' || $ml->result_source->column_info($k)->{'data_type'} eq 'datetime')
                        {
                            $data_to_save = $ml->$attribute;
                        }
                        else
                        {
                            $data_to_save = $ml_columns{$k};
                        }
                        $data->{$k . '_' . $ml_columns{'language'}} = $data_to_save;
                    }
                }
            }
        }
    }
    return $data;
}

sub save_form
{
    my $self = shift;
    my $id = shift;
    my $form = shift;
    
    my $el_row;
    my $el_data;
    my %standby_accessors;
    foreach my $column ($self->get_schema()->resultset($self->ORMObj())->result_source->columns)
    {
        if($column ne 'category' && $column ne 'id' && $column ne 'published')
        {
            if($form->param_value($column))
            {
                if(ref $form->param_value($column) eq 'DateTime')
                {
                    if($self->get_schema()->resultset($self->ORMObj())->result_source->column_info($column)->{'data_type'} eq 'date')
                    {
                        $el_data->{$column} = $form->param_value($column);
                    }
                    else
                    {
                        my $ts = $form->param_value($column);
                        $ts->set_time_zone(config->{'Strehler'}->{'timezone'});
                        $ts->set_time_zone('UTC');
                        $el_data->{$column} = $ts;
                    }
                }
                else
                {
                    $el_data->{$column} = $form->param_value($column);
                }
            }
            else
            {
                my $accessor = $self->can('save_' . $column);
                if($accessor)
                {
                    if($id)
                    {
                        $el_data->{$column} = $self->$accessor($id, $form, undef);
                    }
                    else
                    {
                        $standby_accessors{$column} = $accessor;
                    }
                }
            }
        }
        elsif($column eq 'category')
        {
            my $category;
            if($form->param_value('subcategory'))
            {
                $category = $form->param_value('subcategory');
            }
            elsif($form->param_value('category'))
            {
                $category = $form->param_value('category');
            }
            $el_data->{'category'} = $category;
        }
    }
    if($self->publishable() && $self->auto_publish() && ! $id)
    {
        $el_data->{'published'} = 1;
    }
    if($id)
    {
        $el_row = $self->get_schema()->resultset($self->ORMObj())->find($id);
        $el_row->update($el_data);
    }
    else
    {
        $el_row = $self->get_schema()->resultset($self->ORMObj())->create($el_data);
    }
    my $standby_data;
    foreach(keys %standby_accessors)
    {
        my $accessor = $standby_accessors{$_};
        $standby_data->{$_} = $self->$accessor($el_row->id, $form, undef);
    }
    $el_row->update($standby_data);
    my $children = undef;
    if($id)
    {
        $children = $el_row->can($self->multilang_children());
        $el_row->$children->delete_all() if($children);
    }
    else
    {
        $children = $el_row->can($self->multilang_children());
    }
    if($children)
    {
        my @languages = @{config->{Strehler}->{languages}};
        foreach my $lang (@languages)
        {
            my $to_write = 0;
            my $multi_el_data;
            foreach my $multicolumn ($self->get_schema()->resultset($self->ORMObj())->$children->result_source->columns)
            {
                if($form->param_value($multicolumn . '_' . $lang))
                {
                    if(ref $form->param_value($multicolumn . '_' . $lang) eq 'DateTime')
                    {
                       if($self->get_schema()->resultset($self->ORMObj())->$children->result_source->column_info($multicolumn)->{'data_type'} eq 'date')
                       {
                            $multi_el_data->{$multicolumn} = $form->param_value($multicolumn . '_' . $lang);
                       }
                       else
                       {
                            my $ts = $form->param_value($multicolumn . '_' . $lang);
                            $ts->set_time_zone(config->{'Strehler'}->{'timezone'});
                            $ts->set_time_zone('UTC');
                            $multi_el_data->{$multicolumn} = $ts;
                       }
                    }
                    else
                    {
                        $multi_el_data->{$multicolumn} = $form->param_value($multicolumn . '_' . $lang);
                        $to_write = 1;
                    }    
                }
                else
                {
                    my $accessor = $self->can('save_' . $multicolumn);
                    if($accessor)
                    {
                        $multi_el_data->{$multicolumn} = $self->$accessor($el_row->id, $form, $lang);
                    }
                    $to_write = 1 if $multi_el_data->{$multicolumn};
                }
            }
            if($to_write)
            {
                $multi_el_data->{'language'} = $lang;
                $el_row->$children->create( $multi_el_data );   
            }
        }
    }
    if($form->param_value('tags'))
    {
        Strehler::Meta::Tag->save_tags($form->param_value('tags'), $el_row->id, $self->item_type());
    }
    return $el_row->id;  
}

sub check_role
{
    my $self = shift;
    my $user_role = shift;
    if(! config->{Strehler}->{admin_secured})
    {
        return 1;
    }
    my $role = $self->allowed_role();
    if($role)
    {
        if($user_role eq $role)
        {
            return 1;
        }
        else
        {
            return 0;
        }
    }
    else
    {
        return 1;
    }
}



1;
