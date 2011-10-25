use strict;
use warnings;
# ABSTRACT: When applied to the App::Galaxy::Devel::Tool class takes methods that return strings and executes them over ssh
package App::Galaxy::Devel::Tool::Role::SSH;

use Any::Moose 'Role';
use Net::OpenSSH;
use Carp;

requires 'host';
requires 'ssh_opts';

has 'openssh'  =>  ( isa => 'Net::OpenSSH', is => 'rw', lazy_build => 1 );
has 'openssh_on' => (isa => 'Bool', is => 'rw', default => 1);

sub _build_openssh {
    my $self = shift;
    die "Need to set host" unless defined( $self->host );
    my $ssh = Net::OpenSSH->new( $self->host, %{ $self->ssh_opts } );
    $ssh->error and croak "Couldn't establish SSH connection: ". $ssh->error;
    return $ssh;
}

# ssh
around ['install_remote', 'install_module_remote', 'extract_in_tmp', 'check_custom_tool_dir_exists', 'create_custom_tool_dir',
'copy_to_custom_tool_dir', 'new_section_tool_conf', 'update_section_tool_conf', 'section_exists_tool_conf', 'add_admin',
'restore_remote_tool_conf', 'make_conf_backup', 'read_remote_cpanm_log']
 => sub {
  
   my $orig = shift;
   my $self = shift;
   my $cmd = $self->$orig(@_);	
   
   return $self->$orig(@_) unless $self->openssh_on;      

   my ($stdout, $stderr) = $self->openssh->capture2( $cmd );   
   return [$stdout,$stderr];
};

# ssh for the grep command
# need to pick up the error from ->error, rather than ->stderr
around ['section_tool_grep_tool_conf'] => sub {
   my $orig = shift;
   my $self = shift;
   my $cmd = $self->$orig(@_);	
   
   return $self->$orig(@_) unless $self->openssh_on;
   
   my ($stdout,$stderr) = $self->openssh->capture2( $cmd ); 
   my $error =   $self->openssh->error; 
   return [$stdout, $error];
};

# scp 
around ['send_remote'] => sub {
  
   my $orig = shift;
   my $self = shift;
   my $file = $self->$orig(@_);	
   
   return $self->$orig(@_) unless $self->openssh_on;      

   my ($stdout, $stderr) = $self->openssh->scp_put( {}, $file, "/tmp/" );   
   return [$stdout, $stderr];
};
1;