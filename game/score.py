
def calculate_player_score(self, player_pose):
    if not player_pose:
        return 0
    move = self.get_current_move()
    # Only upper body. Webcam doesn't have enogh FoV and the room is kinda short :(
    score = 0
    for part in BODY_PARTS:
        distance = get_distance(player_pose[part], move[part])
        # 0 distance = 100 score points
        score += 100/(distance + 1) 

    score = score / len(self.body_parts)

    return round(score)