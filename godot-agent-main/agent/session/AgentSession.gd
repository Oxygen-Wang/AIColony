class_name AgentSession
extends RefCounted

## Single conversation session — LLM history and UI transcript.

var id: int = -1
var messages: Array[ChatMessage] = []
var chat_entries: Array[ChatEntry] = []
## Latest LLM request usage; prompt_tokens is the current context length.
var usage: OpenAiUsage = OpenAiUsage.new()


func _init(_id: int = -1) -> void:
	id = _id
	pass
