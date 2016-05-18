immutable LogicTestCase
	description::AbstractString
	initial_state::DandelionWebSockets.SocketState
	rng::FakeRNG
	#frames::Dict{AbstractString, Frame}
	input::Vector{Any} # This will contain types such as FrameFromServer or SendTextFrame
	handler_calls::Vector{MockCall}
	writer_calls::Vector{MockCall}
	final_state::DandelionWebSockets.SocketState
end

function LogicTestCase(;
	description="",
	initial_state=DandelionWebSockets.STATE_CONNECTING,
	rng=FakeRNG(),
	input=[],
	handler_calls=[],
	writer_calls=[],
	final_state=initial_state)

	LogicTestCase(description, initial_state, rng, input, handler_calls, writer_calls, final_state)
end

logic_tests = [

	#
	# Server to client tests
	#

	LogicTestCase(
		description    = "A text message from the server is received",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(b""),
		input          = [DandelionWebSockets.FrameFromServer(test_frame1)],
		handler_calls  = [(symbol("DandelionWebSockets.on_text"), [utf8("Hello")])],
		writer_calls   = []),

	LogicTestCase(
		description    = "Two text fragments are received from the server",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(),
		input          = [DandelionWebSockets.FrameFromServer(test_frame2),
		                  DandelionWebSockets.FrameFromServer(test_frame3)],
		handler_calls  = [(symbol("DandelionWebSockets.on_text"), [utf8("Hello")])],
		writer_calls   = []),

	LogicTestCase(
		description    = "Buffer is cleared between two separate multi-fragment messages",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(),
		input          = [DandelionWebSockets.FrameFromServer(test_frame2),
		                  DandelionWebSockets.FrameFromServer(test_frame3),
		                  DandelionWebSockets.FrameFromServer(test_frame2),
		                  DandelionWebSockets.FrameFromServer(test_frame3)],
		handler_calls  = [(symbol("DandelionWebSockets.on_text"), [utf8("Hello")]),
		                  (symbol("DandelionWebSockets.on_text"), [utf8("Hello")])],
		writer_calls   = []),

	LogicTestCase(
		description    = "A ping request is received between two fragments",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [DandelionWebSockets.FrameFromServer(test_frame2),
						  DandelionWebSockets.FrameFromServer(server_ping_frame),
		                  DandelionWebSockets.FrameFromServer(test_frame3)],
		handler_calls  = [(symbol("DandelionWebSockets.on_text"), [utf8("Hello")])],
		writer_calls   = [(:write, [client_pong_frame])]),

	LogicTestCase(
		description    = "A pong response has the same payload as the ping",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [DandelionWebSockets.FrameFromServer(server_ping_frame_w_pay)],
		handler_calls  = [],
		writer_calls   = [(:write, [client_pong_frame_w_pay])]),


	LogicTestCase(
		description    = "A binary message from the server is received",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(b""),
		input          = [DandelionWebSockets.FrameFromServer(frame_bin_1)],
		handler_calls  = [(symbol("DandelionWebSockets.on_binary"), Array[b"Hello"])],
		writer_calls   = []),

	LogicTestCase(
		description    = "Two binary fragments are received from the server",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(),
		input          = [DandelionWebSockets.FrameFromServer(frame_bin_start),
		                  DandelionWebSockets.FrameFromServer(frame_bin_final)],
		handler_calls  = [(symbol("DandelionWebSockets.on_binary"), Array[b"Hello"])],
		writer_calls   = []),

	#
	# Client to server tests
	#

	LogicTestCase(
		description    = "Client sends a message",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [DandelionWebSockets.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT)],
		handler_calls  = [],
		writer_calls   = [(:write, [test_frame4])]),

	LogicTestCase(
		description    = "Client sends a binary message",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [DandelionWebSockets.SendBinaryFrame(b"Hello", true, OPCODE_BINARY)],
		handler_calls  = [],
		writer_calls   = [(:write, [test_bin_frame4])]),


	LogicTestCase(
		description    = "Client sends two fragments",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(vcat(mask, mask2)),
		input          = [DandelionWebSockets.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT),
		                  DandelionWebSockets.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION)],
		handler_calls  = [],
		writer_calls   = [(:write, [test_frame5]),
		                  (:write, [test_frame6])]),

	LogicTestCase(
		description    = "Frames are not sent when in CLOSING",
		initial_state  = DandelionWebSockets.STATE_CLOSING,
		rng            = FakeRNG(),
		input          = [DandelionWebSockets.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT),
						  DandelionWebSockets.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT),
		                  DandelionWebSockets.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION)],
		handler_calls  = [],
		writer_calls   = []),

	LogicTestCase(
		description    = "Frames are not sent when in CONNECTING",
		initial_state  = DandelionWebSockets.STATE_CONNECTING,
		rng            = FakeRNG(),
		input          = [DandelionWebSockets.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT),
						  DandelionWebSockets.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT),
		                  DandelionWebSockets.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION)],
		handler_calls  = [],
		writer_calls   = []),

	LogicTestCase(
		description    = "Frames are not sent when in CLOSED",
		initial_state  = DandelionWebSockets.STATE_CLOSED,
		rng            = FakeRNG(),
		input          = [DandelionWebSockets.SendTextFrame(utf8("Hello"), true, OPCODE_TEXT),
						  DandelionWebSockets.SendTextFrame(utf8("Hel"), false, OPCODE_TEXT),
		                  DandelionWebSockets.SendTextFrame(utf8("lo"), true, OPCODE_CONTINUATION)],
		handler_calls  = [],
		writer_calls   = []),

	#
	# Closing the connection
	#

	LogicTestCase(
		description    = "The server initiates a closing handshake.",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [DandelionWebSockets.FrameFromServer(server_close_frame)],
		handler_calls  = [(symbol("DandelionWebSockets.state_closing"), [])],
		writer_calls   = [(:write,    [client_close_reply])],
		final_state    = DandelionWebSockets.STATE_CLOSING_SOCKET),

	LogicTestCase(
		description    = "The client initiates a closing handshake.",
		initial_state  = DandelionWebSockets.STATE_OPEN,
		rng            = FakeRNG(mask),
		input          = [DandelionWebSockets.CloseRequest()],
		handler_calls  = [(symbol("DandelionWebSockets.state_closing"), [])],
		writer_calls   = [(:write,    [client_close_reply])],
		final_state    = DandelionWebSockets.STATE_CLOSING),

	LogicTestCase(
		description    = "The server replies to a client initiated handshake",
		initial_state  = DandelionWebSockets.STATE_CLOSING,
		rng            = FakeRNG(),
		input          = [DandelionWebSockets.FrameFromServer(server_close_frame)],
		handler_calls  = [],
		writer_calls   = [],
		final_state    = DandelionWebSockets.STATE_CLOSING_SOCKET),

	LogicTestCase(
		description    = "The socket is closed cleanly",
		initial_state  = DandelionWebSockets.STATE_CLOSING_SOCKET,
		rng            = FakeRNG(),
		input          = [DandelionWebSockets.SocketClosed()],
		handler_calls  = [(symbol("DandelionWebSockets.state_closed"), [])],
		writer_calls   = [],
		final_state    = DandelionWebSockets.STATE_CLOSED),

]

facts("ClientLogic") do
	#
	# Declarative tests
	#

	for test in logic_tests
		context(test.description) do
			mock_handler = MockHandlerTaskProxy(test.handler_calls)
			mock_writer  = MockWriterTaskProxy(test.writer_calls)
			logic = ClientLogic(test.initial_state, mock_handler, mock_writer, test.rng)

			for x in test.input
				DandelionWebSockets.handle(logic, x)
			end

			@fact logic.state --> test.final_state

			check_mock(mock_handler)
			check_mock(mock_writer)
		end
	end


	#
	# Utilities
	#

	context("Masking") do
		hello = b"Hello"
		hel   = b"Hel"
		masked_hello = b"\x7f\x9f\x4d\x51\x58"

		DandelionWebSockets.masking!(hello, mask)
		@fact hello --> b"\x7f\x9f\x4d\x51\x58"

		DandelionWebSockets.masking!(masked_hello, mask)
		@fact masked_hello --> b"Hello"

		DandelionWebSockets.masking!(hel, mask)
		@fact hel --> b"\x7f\x9f\x4d"
	end
end