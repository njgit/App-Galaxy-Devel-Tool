# push distribution over
package App::Galaxy::Devel::Tool::App::Command::admin;
use App::Galaxy::Devel::Tool::App -command;

#core
use strict;
use warnings;
use autodie;
use Try::Tiny;
use App::Galaxy::Devel::Tool;
use Data::Dumper;

sub usage_desc { "galaxp admin [OPTIONS] USER1_EMAIL USER2_EMAIL .." } 

sub abstract { "Creates admin users on the Galaxy cloud instance." }

sub opt_spec {
   my ( $class, $app ) = @_;
   return (
    [ 'no_restart|n' => "No restart" ]
    );
}  

sub validate_args {
  my ($self, $opt, $args) = @_;
  # there should be some args
   die "Requires USER_EMAIL" unless @$args;
} 
  
sub execute {
     my ($self, $opt, $args) = @_;

     my $tool_dev = App::Galaxy::Devel::Tool->new;
     my $out;
     
     try {
      $out = $tool_dev->add_admin($args);   
      print "Added admin users @$args\n";
      unless ( defined( $opt->{no_restart} ) ) {
        print "Attempt to restart galaxy server...\n";
        my $response = $tool_dev->restart_galaxy_cloud_service;
        die ( "Could not restart galaxy .. \ncontent: ", $response->{content}, " reason: ", $response->{reason}, " status code: ", $response->{status} ) unless( $response->{success} );
        print $response->{content}, "\n";
      }
      
         
     } catch {
       die "Error: $_";                 
     };
     
}

1;