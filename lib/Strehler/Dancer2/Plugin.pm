package Strehler::Dancer2::Plugin;
{
    $Strehler::Dancer2::Plugin::VERSION = '1.0.0';
}
use Dancer2::Plugin;

on_plugin_import {
    my $dsl = shift;
    $dsl->prefix('/admin');
    $dsl->set(layout => 'admin');
    $dsl->app->add_hook(
        Dancer2::Core::Hook->new(name => 'before', code => sub {
                my $context = shift;
                return if(! $dsl->config->{Strehler}->{admin_secured});
                if((! $context->session->read('user')) && $context->request->path_info ne $dsl->dancer_app->prefix . '/login')
                {
                    $context->session->{'redir_url'} = $context->request->path_info;
                    my $redir = $dsl->redirect($dsl->dancer_app->prefix . '/login');
                    return $redir;
                }
            }));
    $dsl->app->add_hook(
        Dancer2::Core::Hook->new(name => 'before_template_render', code => sub {
            my $tokens = shift;
            my $match_string = "^" . $dsl->dancer_app->prefix . "\/(.*?)\/";
            my $match_regexp = qr/$match_string/;
            my $path = $dsl->request->path_info();
            my $tab;
            if($path =~ $match_regexp)
            {
                $tab = $1;
            }
            else
            {
                $tab = 'home';
            }
            my %navbar;
            $navbar{$tab} = 'active';
            $tokens->{'navbar'} = \%navbar;
            $tokens->{'extramenu'} = $dsl->config->{Strehler}->{'extra_menu'};
            if(! $dsl->config->{Strehler}->{admin_secured})
            {
                $tokens->{'role'} = 'admin';
                $tokens->{'user'} = 'admin';
            }
            else
            {
                $tokens->{'role'} = $dsl->context->session->read('role');
                $tokens->{'user'} = $dsl->context->session->read('user');
            }
        }));
    };
    

register_plugin for_versions => [ 2 ];

1;

