package Kernel::Language::fr_TicketStateHistory;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    $Self->{Translation}->{'Accounted time stayed in each state :'}
        = 'Temps total passé dans chaque état :';

    $Self->{Translation}->{'Shows a link in the menu to show the state history of a ticket in the ticket zoom view of the agent interface.'}
        = 'Affiche une option dans le menu agent pour voir l\'historique des états du ticket, ainsi que le temps total passé dans chaque état.';
    
    $Self->{Translation}->{'Show the state history of the ticket'}
        = 'Affiche l\'historique des états du ticket';
        
    
    return 1;
}

1;

