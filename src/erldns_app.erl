%% Copyright (c) 2012-2013, Aetrion LLC
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

%% @doc The erldns OTP application.
-module(erldns_app).
-behavior(application).

% Application hooks
-export([start/2, start_phase/3, stop/1]).

start(_Type, _Args) ->
  erldns_metrics:setup(),
  erldns_sup:start_link().

start_phase(post_start, _StartType, _PhaseArgs) ->
  erldns_events:add_handler(erldns_event_handler),

  case application:get_env(erldns, custom_zone_parsers) of
    {ok, Parsers} -> erldns_zone_parser:register_parsers(Parsers);
    _ -> ok
  end,

  case application:get_env(erldns, custom_zone_encoders) of
    {ok, Encoders} -> erldns_zone_encoder:register_encoders(Encoders);
    _ -> ok
  end,

  lager:info("Loading zones from local file"),
  erldns_zone_loader:load_zones(),

  case application:get_env(erldns, zone_server) of
    {ok, _} ->
      lager:info("Loading zones from remote server"),
      erldns_zone_loader:load_remote_zones(),

      lager:info("Websocket monitor connecting"),
      erldns_zoneserver_monitor:connect();
    _ ->
      erldns_events:notify(start_servers)
  end,

  ok.

stop(_State) ->
  lager:info("Stop erldns application"),
  ok.
