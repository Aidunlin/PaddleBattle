extends RigidBody2D

var recent_senders = []

func new_sender(number):
	if recent_senders.has(number):
		recent_senders.remove(recent_senders.find(number))
	recent_senders.push_front(number)
