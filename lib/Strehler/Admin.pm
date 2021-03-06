package Strehler::Admin;
$Strehler::Admin::VERSION = '1.5.1';
use strict;
use Cwd 'abs_path';
use Dancer2 0.154000;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Ajax;
use Strehler::Dancer2::Plugin::Admin;
use HTML::FormFu 1.00;
use HTML::FormFu::Element::Block;
use Authen::Passphrase::BlowfishCrypt;
use Time::localtime;
use Strehler::Helpers; 
use Strehler::Meta::Tag;
use Strehler::Element::Image;
use Strehler::Element::Article;
use Strehler::Element::User;
use Strehler::Element::Log;
use Strehler::Meta::Category;

my @languages;

if(config->{Strehler}->{languages})
{
    @languages = @{config->{Strehler}->{languages}};
}
else
{
    @languages = ('en');
}

my $module_file_path = __FILE__;
my $root_path = abs_path($module_file_path);
$root_path =~ s/Admin\.pm//;

my $form_path = $root_path . 'forms';

set views => $root_path . 'views';

##### Homepage #####

get '/' => sub {
    if(config->{'Strehler'}->{'dashboard_active'} && config->{'Strehler'}->{'dashboard_active'} == 1)
    {
        redirect dancer_app->prefix . '/dashboard/' . config->{'Strehler'}->{'default_language'};
    }
    else
    {
        my %navbar;
        $navbar{'home'} = "active";
        template "admin/index", { navbar => \%navbar};
    }
};

##### Login/Logout #####

any '/login' => sub {
    my $form = form_login();
    my $params_hashref = params;
    $form->process($params_hashref);
    my $message;
    if($form->submitted_and_valid)
    {
        my $user = Strehler::Element::User->valid_login($params_hashref->{'user'}, $params_hashref->{'password'});
        if($user)
        {
            session 'user' => $user->get_attr('user');
            session 'role' => $user->get_attr('role');
            if( session 'redir_url' )
            {
                my $redir = redirect(session 'redir_url');
                return $redir;
            }
            else
            {
                my $redir = redirect(dancer_app->prefix . '/');
                return $redir;
            }
        }
        else
        {
            $message = "Authentication failed!";
        }
    }
    template "admin/login", { form => $form->render(), message => $message }, { layout => 'light-admin' }
};

get '/logout' => sub
{
    session 'user' => undef;
    session 'role' => undef;
    my $redir = redirect(dancer_app->prefix . '/');
    return $redir;
};

ajax '/image/src/:id' => sub
{
    content_type('text/plain');
    my $id = params->{id};
    my $img = Strehler::Element::Image->new($id);
    return $img->get_attr('image');
};

#Users

any '/user/add' => sub
{
    send_error("Access denied", 403) && return if ( ! Strehler::Element::User->check_role(session->read('role')));
    my $form = form_user('add');
    my $params_hashref = params;
    $form->process($params_hashref);
    my $message = "";
    if($form->submitted_and_valid)
    {
        my $id = Strehler::Element::User->save_form(undef, $form);
        if($id == -1)
        {
            $message = "Username already in use";
        }
        else
        {
            Strehler::Element::Log->write(session->read('user'), 'add', 'user', $id);
            redirect dancer_app->prefix . '/user/list';
        }
    }
    template "admin/user", { form => $form->render(), message => $message }
};

get '/user/edit/:id' => sub {
    send_error("Access denied", 403) && return if ( ! Strehler::Element::User->check_role(session->read('role')));
    my $id = params->{id};
    my $user = Strehler::Element::User->new($id);
    my $form_data = $user->get_form_data();
    my $form = form_user('edit');
    $form->default_values($form_data);
    template "admin/user", { form => $form->render() }
};

post '/user/edit/:id' => sub
{
    send_error("Access denied", 403) && return if ( ! Strehler::Element::User->check_role(session->read('role')));
    my $form = form_user('edit');
    my $id = params->{id};
    my $params_hashref = params;
    $form->process($params_hashref);
    my $message;
    if($form->submitted_and_valid)
    {
        my $return_id = Strehler::Element::User->save_form($id, $form);
        if($return_id == -1)
        {
            $message = "Username already in use";
        }
        else
        {
            Strehler::Element::Log->write(session->read('user'), 'edit', 'user', $id);
            redirect dancer_app->prefix . '/user/list';
        }
    }
    template "admin/user", { form => $form->render(), message => $message }
};

get '/user/password' => sub {
    my $user = Strehler::Element::User->get_from_username(session->read('user'));
    my $form_data = $user->get_form_data();
    my $form = form_user('password');
    $form->default_values($form_data);
    template "admin/user", { form => $form->render() }
};
post '/user/password' => sub
{
    send_error("Wrong call", 500) && return if params->{user};
    my $user = Strehler::Element::User->get_from_username(session->read('user'));
    my $id = $user->get_attr('id');
    my $form = form_user('password');
    my $params_hashref = params;
    $form->process($params_hashref);
    my $message;
    if($form->submitted_and_valid)
    {
        my $return_id = Strehler::Element::User->save_password($id, $form);
        if($return_id == -1)
        {
            $message = "Username already in use";
        }
        else
        {
            Strehler::Element::Log->write(session->read('user'), 'change password', 'user', $id);
            redirect dancer_app->prefix . '/';
        }
    }
    template "admin/user", { form => $form->render(), message => $message }
};



#Categories

get '/category' => sub
{
    send_error("Access denied", 403) && return if ( ! Strehler::Meta::Category->check_role(session->read('role')));
    redirect dancer_app->prefix . '/category/list';
};

any '/category/list' => sub
{
    send_error("Access denied", 403) && return && return if ( ! Strehler::Meta::Category->check_role(session->read('role')));

    #THE TABLE
    my $to_view = Strehler::Meta::Category->get_list();
    my @entities = Strehler::Helpers::get_categorized_entities();

    #THE FORM
    my $form = form_category_fast();
    my $params_hashref = params;
    $form->process($params_hashref);
    if($form->submitted_and_valid)
    {
        my $id = Strehler::Meta::Category->save_form(undef, $form, \@entities);
        Strehler::Element::Log->write(session->read('user'), 'add', 'category', $id);
        redirect dancer_app->prefix . '/category/list';
    }
    template "admin/category_list", { categories => $to_view, form => $form };
};

any '/category/add' => sub
{
    send_error("Access denied", 403) && return if ( ! Strehler::Meta::Category->check_role(session->read('role')));
    my $form = form_category();
    my $params_hashref = params;
    my @entities = Strehler::Helpers::get_categorized_entities();
    $form->process($params_hashref);
    if($form->submitted_and_valid)
    {
        my $id = Strehler::Meta::Category->save_form(undef, $form, \@entities);
        Strehler::Element::Log->write(session->read('user'), 'add', 'category', $id);
        redirect dancer_app->prefix . '/category/list'; 
    }
    template "admin/category", { form => $form->render() }
};
get '/category/edit/:id' => sub {
    send_error("Access denied", 403) && return if ( ! Strehler::Meta::Category->check_role(session->read('role')));
    my $id = params->{id};
    my $category = Strehler::Meta::Category->new($id);
    my @entities = Strehler::Helpers::get_categorized_entities();
    my $form_data = $category->get_form_data(\@entities);
    $form_data->{'prev-name'} = $form_data->{'category'};
    $form_data->{'prev-parent'} = $form_data->{'parent'};
    my $form = form_category();
    $form->default_values($form_data);
    template "admin/category", { form => $form->render() }
};
post '/category/edit/:id' => sub
{
    send_error("Access denied", 403) && return if ( ! Strehler::Meta::Category->check_role(session->read('role')));
    my $form = form_category();
    my $id = params->{id};
    my $params_hashref = params;
    my @entities = Strehler::Helpers::get_categorized_entities();
    $form->process($params_hashref);
    if($form->submitted_and_valid)
    {
        Strehler::Meta::Category->save_form($id, $form, \@entities);
        Strehler::Element::Log->write(session->read('user'), 'edit', 'category', $id);
        redirect dancer_app->prefix . '/category/list';
    }
    template "admin/category", { form => $form->render() }
};

get '/category/delete/:id' => sub
{
    send_error("Access denied", 403) && return if ( ! Strehler::Meta::Category->check_role(session->read('role')));
    my $id = params->{id};
    my $category = Strehler::Meta::Category->new($id);
    if($category->has_elements())
    {
        my $message = "Category " . $category->get_attr('category') . " is not empty! Deletion is impossible.";    
        my $return = dancer_app->prefix . "/category/list";
        template "admin/message", { message => $message, backlink => $return };
    }
    elsif($category->is_parent())
    {
        my $message = "Category " . $category->get_attr('category') . " has subcategories! Deletion is impossible.";    
        my $return = dancer_app->prefix . "/category/list";
        template "admin/message", { message => $message, backlink => $return };
    }
    else
    {
        my %data = $category->get_basic_data();
        template "admin/delete", { what => "category", el => \%data, backlink => dancer_app->prefix . '/category' };
    }
};
post '/category/delete/:id' => sub
{
    send_error("Access denied", 403) && return if ( ! Strehler::Meta::Category->check_role(session->read('role')));
    my $id = params->{id};
    my $category = Strehler::Meta::Category->new($id);
    $category->delete();
    Strehler::Element::Log->write(session->read('user'), 'delete', 'category', $id);
    redirect dancer_app->prefix . '/category/list';
};

ajax '/category/select/:id' => sub
{
    content_type('text/plain');
    my $id = params->{id};
    my $option = params->{option} || undef;
    my $data = Strehler::Meta::Category->make_select($id, $option);
    if($data->[1])
    {
        template 'admin/category_select', { categories => $data }, { layout => undef };
    }
    else
    {
        return 0;
    }
};
ajax '/category/select' => sub
{
    content_type('text/plain');
    my $data = Strehler::Meta::Category->make_select(undef);
    if($data->[1])
    {
        template 'admin/category_select', { categories => $data }, { layout => undef };
    }
    else
    {
        return 0;
    }
};
ajax '/category/tagform/:type/:id?' => sub
{
    content_type('text/plain');
    if(params->{id})
    {
        my $category = Strehler::Meta::Category->new(params->{id});
        if(! $category->exists())
        {
            template 'admin/open_tags';
        }
        else
        {
            my @tags = Strehler::Meta::Tag->get_configured_tags_for_template($category->ext_name(), params->{type});
            if($#tags > -1)
            {
                template 'admin/configured_tags', { tags => \@tags }, { layout => undef };
            }
            else
            {
                template 'admin/open_tags';
            }
        }
    }
    else
    {
        template 'admin/open_tags';
    }
};

get '/:entity' => sub
{
    my $entity = params->{entity};
    my $class = Strehler::Helpers::class_from_entity($entity);
    if($class)
    {
        send_error("Access denied", 403) && return if ( ! $class->check_role(session->read('role')));
        redirect dancer_app->prefix . '/' . $entity . '/list';
    }
    else
    {
        return pass;
    }
};

any '/:entity/list' => sub
{
    my $entity = params->{entity};
    my $class = Strehler::Helpers::class_from_entity($entity);
    if(! $class->auto())
    {
        return pass;
    }
    send_error("Access denied", 403) && return if ( ! $class->check_role(session->read('role')));

    my $custom_list_template = $class->custom_list_template();
    my $list_view = $custom_list_template ? 'admin/custom_list' : 'admin/generic_list';
    
    my $page = exists params->{'page'} ? params->{'page'} : session $entity . '-page';
    my $cat_param = exists params->{'cat'} ? params->{'cat'} : session $entity . '-cat-filter';
    my $order = exists params->{'order'} ? params->{'order'} : session $entity . '-order';
    my $order_by = exists params->{'order-by'} ? params->{'order-by'} : session $entity . '-order-by';
    my $search = exists params->{'search'} ? params->{'search'} : session $entity . '-search';
    my $ancestor = exists params->{'ancestor'} ? params->{'ancestor'} : session $entity . '-ancestor';
    my $language = exists params->{'language'} ? params->{'language'} : session $entity . '-language';
    my $wanted_cat = undef;
    if(exists params->{'strehl-catname'})
    {
        $wanted_cat = Strehler::Meta::Category->explode_name(params->{'strehl-catname'});
        if(! $wanted_cat->exists())
        {
           my $backlink = params->{'strehl-from'} || "/admin/$entity/list";
           return template "admin/message", { message => "No elements in category: " . params->{'strehl-catname'}, backlink => $backlink }; 
        }
        $cat_param = $wanted_cat->get_attr('id');
    }
    else
    {
        if($cat_param)
        {
            $wanted_cat = Strehler::Meta::Category->new($cat_param);
        }
    }
    my $backlink = params->{'strehl-from'};
    my $cat = undef;
    my $subcat = undef;
    if($wanted_cat)
    {
        if($wanted_cat->row->parent)
        {
            $cat = $wanted_cat->row->parent->id;
            $subcat = $wanted_cat->row->id;
        }
        else
        {
            $cat = $wanted_cat->row->id;
        }
    }
    if(exists params->{'cat_name'} || exists params->{'cat'})
    {
        $ancestor = undef;
    }
    elsif(exists params->{'ancestor'})
    {
        $cat_param = undef;
        $cat = $ancestor;
        $subcat = '*';
    }
    $page ||= 1;
    $order ||= 'desc';
    my $entries_per_page = 20;
    my $search_parameters = { page => $page, entries_per_page => $entries_per_page, category_id => $cat_param, ancestor => $ancestor, order => $order, order_by => $order_by, language => $language};
    my $elements;
    if($search)
    {
        $elements = $class->search_box($search, $search_parameters);
    }
    else
    {
        $elements = $class->get_list($search_parameters);
    }
    session $entity . '-page' => $page;
    session $entity . '-cat-filter' => $cat_param;
    session $entity . '-order' => $order;
    session $entity . '-order-by' => $order_by;
    session $entity . '-search' => $search;
    session $entity . '-ancestor' => $ancestor;
    session $entity . '-language' => $language;
    template $list_view, { entity => $entity, elements => $elements->{'to_view'}, page => $page, cat_filter => $cat, subcat_filter => $subcat, search => $search, order => $order, order_by => $order_by, fields => $class->fields_list(), last_page => $elements->{'last_page'}, $class->entity_data(), custom_list_template => $custom_list_template, backlink => $backlink, language => $language, languages => \@languages };
};
get '/:entity/turnon/:id' => sub
{
    my $entity = params->{entity};
    my $redirect = params->{'strehl-from'} || dancer_app->prefix . '/'. $entity . '/list';
    my $class = Strehler::Helpers::class_from_entity($entity);
    if((! $class->auto()) || (! $class->publishable()))
    {
        return pass;
    }
    send_error("Access denied", 403) && return if ( ! $class->check_role(session->read('role')));
    my $id = params->{id};
    my $obj = $class->new($id);
    $obj->publish();
    Strehler::Element::Log->write(session->read('user'), 'publish', $entity, $id);
    redirect $redirect;
};
get '/:entity/turnoff/:id' => sub
{
    my $entity = params->{entity};
    my $redirect = params->{'strehl-from'} || dancer_app->prefix . '/'. $entity . '/list';
    my $class = Strehler::Helpers::class_from_entity($entity);
    if((! $class->auto()) || (! $class->publishable()))
    {
        return pass;
    }
    send_error("Access denied", 403) && return if ( ! $class->check_role(session->read('role')));
    my $id = params->{id};
    my $obj = $class->new($id);
    $obj->unpublish();
    Strehler::Element::Log->write(session->read('user'), 'unpublish', $entity, $id);
    redirect $redirect;
};
get '/:entity/delete/:id' => sub
{
    my $entity = params->{entity};
    my $class = Strehler::Helpers::class_from_entity($entity);
    if((! $class->auto()) || (! $class->deletable()))
    {
        return pass;
    }
    send_error("Access denied", 403) && return if ( ! $class->check_role(session->read('role')));
    my $id = params->{id};
    my $obj = $class->new($id);
    my %el = $obj->get_basic_data();
    template "admin/delete", { what => $class->label(), el => \%el, backlink => dancer_app->prefix . '/' . $entity };
};
post '/:entity/delete/:id' => sub
{
    my $entity = params->{entity};
    my $class = Strehler::Helpers::class_from_entity($entity);
    if((! $class->auto()) || (! $class->deletable()))
    {
        return pass;
    }
    send_error("Access denied", 403) && return if ( ! $class->check_role(session->read('role')));
    my $id = params->{id};
    my $obj = $class->new($id);
    $obj->delete();
    Strehler::Element::Log->write(session->read('user'), 'delete', $entity, $id);
    redirect dancer_app->prefix . '/' . $entity . '/list';
};
ajax '/:entity/tagform/:id?' => sub
{
    content_type('text/plain');
    my $entity = params->{entity};
    my $class = Strehler::Helpers::class_from_entity($entity);
    if((! $class->auto()) || (! $class->categorized()))
    {
        return pass;
    }
    if(params->{id})
    {
        my $obj = $class->new(params->{id});
        my @category_tags = Strehler::Meta::Tag->get_configured_tags_for_template($obj->get_attr('category-name'), $entity);
        my @tags = split(',', $obj->get_tags());
        my @out;
        if($#category_tags > -1)
        {
            foreach my $c_t (@category_tags)
            {
                my $default = 0;
                if (grep {$_ eq $c_t->tag} @tags) 
                {
                    $default = 1;
                }
                push @out, { tag => $c_t->tag, default_tag => $default };
            }
            template 'admin/configured_tags', { tags => \@out };
        }
        else
        {
            template 'admin/open_tags', { tags => $obj->get_tags() };
        }
    }
    else
    {
           template 'admin/open_tags';
    }
};
ajax '/:entity/lastchapter/:id?' => sub
{
    content_type('text/plain');
    my $entity = params->{entity};
    my $id = params->{id} || undef;
    my $class = Strehler::Helpers::class_from_entity($entity);
    if((! $class->auto()) || (! $class->ordered()))
    {
        return pass;
    }
    return $class->max_category_order($id) +1;
};

any '/:entity/add' => sub
{
    my $entity = params->{entity};
    my $class = Strehler::Helpers::class_from_entity($entity);
    if((! $class->auto()) || (! $class->creatable()))
    {
        return pass;
    }

    my $check_cat = Strehler::Meta::Category->no_categories();
    if($check_cat and $class->categorized())
    {
        my $message = "No category in the system. Create a category before creating categorized content.";    
        my $return = dancer_app->prefix . "/";
        my $create = dancer_app->prefix . "/category/add";
        return template "admin/no_category", { message => $message, backlink => $return, createlink => $create };
    }

    send_error("Access denied", 403) && return if ( ! $class->check_role(session->read('role')));
    my $form = form_generic($class->form(), $class->multilang_form(), 'add'); 
    my $params_hashref = params;
    $form = Strehler::Admin::tags_for_form($form, $params_hashref);
    if(! $form)
    {
        return pass;
    }
    $form->process($params_hashref);
    my $message = 'quiet';
    if($form->submitted_and_valid)
    {
        my $id = $class->save_form(undef, $form, request->uploads());
        Strehler::Element::Log->write(session->read('user'), 'add', $entity, $id);
        my $action = params->{'strehl-action'};
        if(! $action)
        {
            if(session->read('backlink'))
            {
                redirect session->read('backlink');
            }
            else
            {
                redirect dancer_app->prefix . '/' . $entity . '/list';
            }
        }
        elsif($action eq 'submit-go')
        {
            if(session->read('backlink'))
            {
                redirect session->read('backlink');
            }
            else
            {
                redirect dancer_app->prefix . '/' . $entity . '/list';
            }
        }
        elsif($action eq 'submit-continue')
        {
            redirect dancer_app->prefix . '/' . $entity . '/edit/' . $id . '?from_add=1';
        }
    }
    my $fake_tags = $form->get_element({ name => 'tags'});
    $form->remove_element($fake_tags) if($fake_tags);
    my $backlink = undef;
    if(request->method eq 'GET')
    {
        my $wanted_cat;
        if(exists params->{'strehl-catname'})
        {
            $wanted_cat = Strehler::Meta::Category->explode_name(params->{'strehl-catname'});
            if($wanted_cat->exists())
            {
                my $parent = $wanted_cat->get_attr('parent');
                if($parent)
                {
                    $form->default_values({ category => $parent, subcategory => $wanted_cat->get_attr('id')});
                }
                else
                {
                    $form->default_values({ category => $wanted_cat->get_attr('id')});
                }
            }    
        }
        if(exists params->{'strehl-today'})
        {
            my $tm = localtime;
            my $tm_day = $tm->mday;
            my $tm_month = $tm->mon + 1;
            my $tm_year = $tm->year + 1900;
            my $date_string = "$tm_day/$tm_month/$tm_year";
            $form->default_values({ publish_date => $date_string });
        }
        if(exists params->{'strehl-max-order'})
        {
            if($wanted_cat && $wanted_cat->exists())
            {
                my $max = $class->max_category_order($wanted_cat->get_attr('id')) + 1;
                $form->default_values({ display_order => $max });
            }
        }
        if(exists params->{'strehl-from'})
        {
            $backlink = params->{'strehl-from'};
            session 'backlink' => params->{'strehl-from'};
        }
        else
        {
            session 'backlink' => undef;
        }
    }
    $backlink = $backlink || session->read('backlink');
    my %conf_data = $class->entity_data();
    template "admin/generic_add", { entity => $entity, label => $class->label(), form => $form->render(), custom_snippet => $class->custom_add_snippet(), entity_conf => \%conf_data, backlink => $backlink }
};
get '/:entity/edit/:id' => sub {
    my $id = params->{id};
    my $entity = params->{entity};
    my $from_add = params->{from_add} || 0;
    my $class = Strehler::Helpers::class_from_entity($entity);
    my $backlink = undef;
    if((! $class->auto()) || (! $class->updatable()))
    {
        return pass;
    }
    if(exists params->{'strehl-from'})
    {
        $backlink = params->{'strehl-from'};
        session 'backlink' => params->{'strehl-from'};
    }
    else
    {
        if(! $from_add)
        {
            session 'backlink' => undef;
        }
    }
    send_error("Access denied", 403) && return if ( ! $class->check_role(session->read('role')));
    my $el = $class->new($id);
    my $form_data = $el->get_form_data();
    my $form = form_generic($class->form(), $class->multilang_form(), 'edit', $form_data->{'category'}); 
    if(! $form)
    {
        return pass;
    }
    $form->default_values($form_data);
    my %conf_data = $class->entity_data();
    my $message = $from_add ? 'saved' : 'quiet';
    $backlink = $backlink || session->read('backlink');
    template "admin/generic_add", {  entity => $entity, label => $class->label(), id => $id, form => $form->render(), message => $message, custom_snippet => $el->custom_add_snippet(), entity_conf => \%conf_data, backlink => $backlink }
};
post '/:entity/edit/:id' => sub
{
    my $id = params->{id};
    my $entity = params->{entity};
    my $class = Strehler::Helpers::class_from_entity($entity);
    if((! $class->auto()) || (! $class->updatable()))
    {
        return pass;
    }
    send_error("Access denied", 403) && return if ( ! $class->check_role(session->read('role')));
    my $form = form_generic($class->form(), $class->multilang_form(), 'edit'); 
    if(! $form)
    {
        return pass;
    }
    my $params_hashref = params;
    $form = Strehler::Admin::tags_for_form($form, $params_hashref);
    $form->process($params_hashref);
    my $message = 'quiet';
    if($form->submitted_and_valid)
    {
        $class->save_form($id, $form, request->uploads());
        Strehler::Element::Log->write(session->read('user'), 'edit', $entity, $id);
        my $action = params->{'strehl-action'};
        if(! $action)
        {
            if(session->read('backlink'))
            {
                redirect session->read('backlink');
            }
            else
            {
                redirect dancer_app->prefix . '/' . $entity . '/list';
            }
        }
        elsif($action eq 'submit-go')
        {
            if(session->read('backlink'))
            {
                redirect session->read('backlink');
            }
            else
            {
                redirect dancer_app->prefix . '/' . $entity . '/list';
            }
        }
        elsif($action eq 'submit-continue')
        {
            $message = 'saved';
        }
    }
    my $el = $class->new($id);
    my %conf_data = $class->entity_data();
    my $backlink = session->read('backlink');
    template "admin/generic_add", { entity => $entity, label => $class->label(), id => $id, form => $form->render(), message => $message, custom_snippet => $el->custom_add_snippet(), entity_conf => \%conf_data, backlink => $backlink }
};

##### DASHBOARD #####

get '/dashboard/:lang' => sub {
    if(! config->{'Strehler'}->{'dashboard_active'} || config->{'Strehler'}->{'dashboard_active'} == 0)
    {
        return pass;
    }
    my %navbar;
    $navbar{'home'} = "active";
    my $language = params->{'lang'};
    my $dashboard_data = config->{'Strehler'}->{'dashboard'};
    my $elid = 0;
    foreach my $el (@{$dashboard_data})
    {
        $el->{id} = $elid++;
        if($el->{'type'} eq 'list')
        {
            my $class = Strehler::Helpers::class_from_entity($el->{'entity'});
            my $elements = $class->get_list({ entries_per_page => -1, 
                                              category => $el->{'category'}, 
                                              language => $language,
                                              published => 1
                                            });
            my @list = @{$elements->{'to_view'}};
            $el->{'counter'} = $#list+1;
            my $unpub_elements = $class->get_list({ entries_per_page => -1, 
                                              category => $el->{'category'}, 
                                              language => $language,
                                              published => 0
                                            });
            my @unpub_list = @{$unpub_elements->{'to_view'}};
            $el->{'unpublished_counter'} = $#unpub_list+1;
            my $by = $el->{'by'} || 'date';
            $el->{'by'} = $by;
        }
        elsif($el->{'type'} eq 'page')
        {
            my $total_elements = 0;
            my $published_elements = 0;
            foreach my $piece (@{$el->{'elements'}})
            {
                $total_elements++;
                my $class = Strehler::Helpers::class_from_entity($piece->{'entity'});
                my $by = $piece->{'by'} || 'date';
                $piece->{'by'} = $by;
                my ($latest_published, $latest_unpublished) = $class->get_last_pubunpub($piece->{'category'}, $language, $by);
                if($latest_unpublished)
                {
                    my %latest_unpub_data = $latest_unpublished->get_ext_data($language);
                    $piece->{'latest_unpublished'} = \%latest_unpub_data;
                }
                else
                {
                    $piece->{'latest_unpublished'} = undef;
                }
                if($latest_published)
                {
                    $published_elements++;
                    my %latest_pub_data = $latest_published->get_ext_data($language);
                    $piece->{'latest_published'} = \%latest_pub_data;
                }
                else
                {
                    $piece->{'latest_published'} = undef;
                }
            }
            $el->{'published_elements'} = $published_elements;
            $el->{'total_elements'} = $total_elements;
        }
    }
    template "admin/dashboard", { language => $language, languages => \@languages, navbar => \%navbar, dashboard => config->{'Strehler'}->{'dashboard'}};
};




##### Helpers #####
# They only manipulate form rendering and ACL

sub form_login
{
    my $form = HTML::FormFu->new;
    $form->auto_error_class('error-msg');
    $form->load_config_file( $form_path . '/admin/login.yml' );
    return $form;    
}

sub form_category
{
    my $form = HTML::FormFu->new;
    $form->auto_error_class('error-msg');
    $form->load_config_file( $form_path . '/admin/category.yml' );
    my $category = $form->get_element({ name => 'parent'});
    $category->options(Strehler::Meta::Category->make_select());
    $form = add_dynamic_fields_for_category($form); 
    my $prev_name = $form->element( { type => 'Hidden', name => 'prev-name'} );
    my $prev_parent = $form->element( { type => 'Hidden', name => 'prev-parent'} );
    my $position = $form->get_element({ name => 'save' });
    $form->insert_before($prev_name, $position);
    $form->insert_before($prev_parent, $position);
    return $form;
}

sub form_category_fast
{
    my $form = HTML::FormFu->new;
    $form->auto_error_class('error-msg');
    $form->load_config_file( $form_path . '/admin/category_fast.yml' );
    my $parent = $form->get_element({ name => 'parent'});
    $parent->options(Strehler::Meta::Category->make_select());
    return $form;
}

sub form_user
{
    my $action = shift;
    my $form = HTML::FormFu->new;
    $form->auto_error_class('error-msg');
    $form->load_config_file( $form_path . '/admin/user.yml' );
    if($action eq 'add')
    {
        $form->constraint({ name => 'password', type => 'Required' }); 
        $form->constraint({ name => 'password-confirm', type => 'Required' }); 
        $form->constraint({ name => 'user', type => 'Required' }); 
    }
    elsif($action eq 'edit')
    {
        $form->constraint({ name => 'user', type => 'Required' }); 
    }
    elsif($action eq 'password')
    {
        my $user = $form->get_element({ name => 'user' });
        $user->attributes->{readonly} = 'readonly';
        $user->attributes->{disabled} = 'disabled';
        my $role = $form->get_element({ name => 'role' });
        $role->attributes->{readonly} = 'readonly';
        $role->attributes->{disabled} = 'disabled';
    }
    return $form;
}

sub form_generic
{
    my $conf = shift;
    my $multilang_conf = shift;
    my $action = shift;
    my $has_sub = shift;
    if(! $conf)
    {
        return undef;
    }

    my $form = HTML::FormFu->new;
    $form->auto_error_class('error-msg');
    $form->load_config_file( $conf );
    if($multilang_conf)
    {
        $form = add_multilang_fields($form, \@languages, $multilang_conf); 
    }
    my $category_block = $form->get_element({ name => 'categoryblock'});
    my $category = $category_block ?
        $category_block->get_element({ name => 'category'}) :
        $form->get_element({ name => 'category'});
    if($category)
    {
       $category->options(Strehler::Meta::Category->make_select());
       my $subcategory = $category_block ?
            $category_block->get_element({ name => 'subcategory'}) :
            $form->get_element({ name => 'subcategory'});
       if($subcategory)
       {
           $subcategory->options(Strehler::Meta::Category->make_select($has_sub));
       }
    }
    return $form;
}


sub tags_for_form
{
    my $form = shift;
    my $params_hashref = shift;
    if($params_hashref->{'configured-tag'})
    {
        if(ref($params_hashref->{'configured-tag'}) eq 'ARRAY')
        {
            $params_hashref->{'tags'} = join(',', @{$params_hashref->{'configured-tag'}});
        }
        else
        {
            $params_hashref->{'tags'} = $params_hashref->{'configured-tag'};
        }
        my $position = $form->get_element({ name => 'categoryblock'}) || $form->get_element({ name => 'subcategory'});
        $form->insert_after($form->element({ type => 'Text', name => 'tags'}), $position);
    }
    elsif($params_hashref->{'tags'})
    { 
        my $position = $form->get_element({ name => 'categoryblock'}) || $form->get_element({ name => 'subcategory'});
        $form->insert_after($form->element({ type => 'Text', name => 'tags'}), $position);
    }
    return $form;
}

sub add_multilang_fields
{
    my $form = shift;
    my $lan_ref = shift;
    my $config = shift;
    my $position = $form->get_element({ name => 'save' });
    for(@{$lan_ref})
    {
        my $lan = $_;
        my $form_multilan = HTML::FormFu->new;
        $form_multilan->load_config_file($config);
        for(@{$form_multilan->get_elements()})
        {
            my $el = $_;
            $el->name($el->name() . '_' . $lan);
            $el->label($el->label . " (" . $lan . ")");
            $form->insert_before($_->clone(), $position);
        }
    }
    return $form;
}

sub add_dynamic_fields_for_category
{
    my $form = shift;
    my $config = $form_path . '/admin/category_dynamic.yml';
    my $position = $form->get_element({ name => 'save' });
    for(Strehler::Helpers::get_categorized_entities())
    {
        my $ent = $_;
        my $form_dyna = HTML::FormFu->new;
        my $fieldset = HTML::FormFu::Element::Fieldset->new;
        $fieldset->element( { name => 'placeholder', type => 'Blank' } );
        my $f_position = $fieldset->get_element( { name => 'placeholder' } );
        $form_dyna->load_config_file($config);
        for(@{$form_dyna->get_elements()})
        {
            my $el = $_;
            if(ref($el) eq "HTML::FormFu::Element::Block")
            {
                $el->content("Per " . $ent);
                $el->name($el->name() . '-' . $ent);
                $fieldset->insert_before($el->clone(), $f_position);
            }
            else
            {
                $el->name($el->name() . '-' . $ent);
                $fieldset->insert_before($el->clone(), $f_position);
            }
        }
        $form->insert_before($fieldset->clone(), $position);
    }
    return $form;
}

=encoding utf8

=head1 NAME

Strehler::Admin - App holding the routes used by Strehler backend

=head1 DESCRIPTION

Strehler::Admin holds all the routes used by Strehler to erogate views. It also contains some helpers, mostly about form management, called inside routes.

The use of the L<Strehler::Dancer2::Plugin::Admin> makes all the routes to have /admin as prefix.

Routes have the structure:

    /entity/action/id

Where  B<entity> represent a L<Strehler::Element> class, action is usually a standard action of a CRUD interface and id (where needed) is the identifier of the object cosidered.

=head1 SYNOPSIS

Strehler::Admin is just a Dancer2 app so you need to add it to your bin/app.pl script to use it.

    #!/usr/bin/env perl

    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use Site;
    use Strehler::Admin;

    Site->dance;

Never add the C<use Strehler::Admin> line as the first App included to not mess with site directories (public, lib...)

=cut


1;
