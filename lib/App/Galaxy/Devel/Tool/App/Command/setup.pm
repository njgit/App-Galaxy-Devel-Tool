# push distribution over
package App::Galaxy::Devel::Tool::App::Command::setup;
use App::Galaxy::Devel::Tool::App -command;

#core
use strict;
use warnings;
use autodie;

#cpan modules
use Config::Tiny;
use Config::YAML::Tiny;
use YAML::Tiny;
use autobox::Core;
use IO::All;
use Data::Dumper;
use File::Spec::Functions;
use Try::Tiny;
use App::Cmd::Tester;
use App::Galaxy::Devel::Tool::App;
use App::Galaxy::Devel::Tool;

sub usage_desc { "galaxp setup [OPTIONS]" } 
sub abstract {
  "Runs all commands written in a setup config file."
}

sub opt_spec {
   my ( $class, $app ) = @_;
    return ( 
           [ 'key_path|k=s' => "Path to pem key" ],
           [ 'host|h=s' => "URL to galaxy cloud server"],
           [ 'user|u=s' => "user name (default is ubuntu)"],
           [ 'path|p' => "prints path to setup file"],       
    );
}  

sub validate_args {
  my ($self, $opt, $args) = @_;

  if( defined( $opt->{host} ) ) {
    $self->usage_error( "Please enter a valid host name e.g. ec2-67-202-53-53.compute-1.amazonaws.com\n" )  unless is_hostname( $opt->{host} );  
  } 
  
  if( defined ( $opt->{key_path} ) ) {
   #$self->usage_error( 'Path name must be absolute. e.g /home/user/key.pem, c:\keys\key.pem'."\n" ) unless file_name_is_absolute( $opt->{key_path} );
   $self->usage_error( "File path for key does not exist\n") unless ( -e $opt->{key_path} );     
  }
}

sub execute {
    my ($self, $opt, $args) = @_;
    #
    init();
   
    run_setup( $self , $opt ) unless ( ( @$args > 0 ) or ( $opt->{path} ) ); #run if args are empty
    
    if ( $opt->{path} ){
      App::Galaxy::Devel::Tool->new->local_config_setup_file_path->concat("\n")->print; 
    }
}      

sub init {

    my $tool_dev = App::Galaxy::Devel::Tool->new;
     
    # Make directory .galaxy in std directory 
    my $config_dir =  catdir( $tool_dev->local_config_basename, $tool_dev->local_config_dirname  );
    print "Creating directory $config_dir..\n" unless ( stat( $config_dir ) ); 
    make_path($config_dir) unless ( stat( $config_dir ) );    
    
    # Read unless it does not exists
    my $setup_file = $tool_dev->local_config_setup_file_path;
    my $ym = YAML::Tiny->new;
    
    if(!stat($setup_file)) {
      $ym->[0]->{'commands'} 
        = [
            'install http://cpan.metacpan.org/authors/id/L/LE/LEMBARK/FindBin-libs-1.51.tar.gz',
            'install Moose',
            'install MooseX::Types::Moose',             
        ];
      $ym->write($setup_file);
    } 
}

sub run_setup {
  my $self = shift;
  #open config_file
   my $tool_dev = App::Galaxy::Devel::Tool->new;
   my $ym = YAML::Tiny->read( $tool_dev->local_config_setup_file_path);
   $ym->[0]->{commands}->foreach(
                      sub {
                       "Executing command: "->concat($_[0]."...\n")->print;
                       my $response = test_app( 'App::Galaxy::Devel::Tool::App' => [ $_[0]->split('\s+') ]);
                       $response->output->concat("\n")->print; 
                       print STDERR $response->error if ( defined( $response->error) ) ; 
                      });
}


sub speak {
  my $out = shift;
  if(ref($out) eq 'ARRAY') {
    for ( 0 .. @$out-1 ) { print $out->[$_], "\n"; }    
  }; 
}

1;

