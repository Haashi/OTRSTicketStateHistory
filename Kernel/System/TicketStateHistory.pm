# Copyright (C) 2017 Haashii

package Kernel::System::TicketStateHistory;

use strict;
use warnings;

our @ObjectDependencies = (
  'Kernel::System::DB',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless ($Self, $Type);

    return $Self;
}

sub GetTicketStateHistoryText {

    my ( $Self, $Param ) = @_;

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    
    $DBObject->Connect();

    my $ticketid=$Param;

    #Credits to Crythias for this query
    my $requete="SELECT u.login                                                             owner,
           ts.name                                                             state,
           th.name                                                             fromto
           ,
           th.create_time
           createtime,
           th.ticket_id
           ticket_id,
           Coalesce((SELECT th2.create_time
                     FROM   ticket_history th2
                     WHERE  th2.history_type_id IN ( '1', '27' )
                            AND th2.ticket_id = th.ticket_id
                            AND th2.id > th.id
                     LIMIT  1), Now())
           custom_date,
           Timestampdiff(second, th.create_time, Coalesce(
           (SELECT th2.create_time
            FROM   ticket_history th2
            WHERE  th2.history_type_id IN (
                   '1', '27' )
                   AND th2.ticket_id =
                       th.ticket_id
                   AND th2.id > th.id
            LIMIT  1), Now())) diff
    FROM   `ticket_history` th
           LEFT JOIN users u
                  ON u.id = th.owner_id
           LEFT JOIN ticket_state ts
                  ON ts.id = th.state_id
    WHERE  th.history_type_id IN ( '1', '27' ) and ticket_id=".$ticketid."
    ORDER  BY createtime desc;";

    $DBObject->Prepare(SQL   => $requete,);
    
    #accounts the total time spent in each unique state
    my %Time=();
    my $day;
    my $minute;
    my $hour;
    my $second;
    
    while(my @row = $DBObject->FetchrowArray()){
      my ($agent,$state,$notused,$startdate,$id,$enddate,$diff)=@row;
      if(defined $Time{$state}){
        $Time{$state}+=$diff;
      }
      else{
        $Time{$state}=$diff;
      }
    }
    
    $DBObject->Disconnect();
    #Build the text output
    my $Text="";
    foreach (keys %Time) {
      if( $Time{$_}<60){
        $Text="The ticket stayed in the $_ state for $Time{$_} sec.\n".$Text;
      }
      elsif( $Time{$_}<3600){
        $minute=int( $Time{$_}/60);
        $second= $Time{$_}%60;
        $Text="The ticket stayed in the $_ state for $minute min and $second sec.\n".$Text;
      }
      elsif( $Time{$_}<3600*24){
        $hour=int( $Time{$_}/3600);
        $minute=int(( $Time{$_}-$hour*3600)/60);
        $second= $Time{$_}-3600*$hour-$minute*60;
        $Text= "The ticket stayed in the $_ state for $hour h, $minute min and $second sec \n".$Text;
      }
      else{
        $day=int( $Time{$_}/(3600*24));
        $hour=int(( $Time{$_}-$day*3600*24)/3600);
        $minute=int(( $Time{$_}-$day*3600*24-3600*$hour)/60);
        $second=( $Time{$_}-$day*3600*24-3600*$hour)-$minute*60;
        $Text= "The ticket stayed in the $_ state for $day d, $hour h, $minute min and $second sec \n".$Text;
      }
    }

  return $Text;
}
1;
