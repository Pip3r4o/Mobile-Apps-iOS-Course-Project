//
//  GameScene.swift
//  JustAnotherSpaceGame
//
//  Created by Peter on 03/02/2016.
//  Copyright (c) 2016 PeterK. All rights reserved.
//

import SpriteKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
    var score = 0;
    var scoreNode = SKLabelNode();
    
    var lifeNodes : [SKSpriteNode] = [];
    
    var background = SKSpriteNode(imageNamed: "background.jpg");
    
    var player : Player? = nil;
    var motionManager = CMMotionManager();
    var destX = CGFloat(0.0);
    
    var enemySpawnTimer : NSTimer? = nil;
    var playerProjectilesTimer : NSTimer? = nil;
    
    var enemySpawnRate = 1.0;
    var enemySpawnRateDelta = 0.05;
    var minEnemyVelocity = 25;
    var maxEnemyVelocity = 45;
    var shootingRate = 0.4;
    var scorePerEnemyKilled = 50;
    var gameDifficulty = 1;
    var remainingLives = INITIAL_LIVES;
    var playerIsInvincible = false;
    
    var gamePaused = false;
    
    var hasAccelerometer = true;
    
    var playingSceneXOffset = CGFloat(0);
    
    func createHUD() {
        let hud = SKSpriteNode(color: UIColor.blackColor(), size: CGSizeMake(self.size.width, self.size.height * 0.05))
        hud.anchorPoint = CGPointMake(0, 0);
        hud.position = CGPointMake(0, self.size.height - hud.size.height);
        hud.zPosition = 10;
        self.addChild(hud);
        
        // Display the remaining lifes
        // Add icons to display the remaining lifes
        // Reuse the Spaceship image: Scale and position releative to the HUD size
        let lifeSize = CGSizeMake(hud.size.height - 10, hud.size.height - 10)
        
        for(var i = 0; i < self.remainingLives; i++) {
            let tmpNode = SKSpriteNode(imageNamed: "ship.png");
            lifeNodes.append(tmpNode);
            tmpNode.size = lifeSize;
            tmpNode.position = CGPointMake((hud.size.width/12) + tmpNode.size.width * 1.1 * (1.0 + CGFloat(i)), 15);
            hud.addChild(tmpNode);
        }
        
        // Pause button container and label
        // Needed to increase the touchable area
        // Names will be used to identify these elements in the touch handler
        let pauseContainer = SKSpriteNode();
        pauseContainer.position = CGPointMake(hud.size.width/1.2, 15);
        pauseContainer.size = CGSizeMake(hud.size.height * 3, hud.size.height * 1.5);
        pauseContainer.name = "PauseButtonContainer";
        hud.addChild(pauseContainer);
        
        let pauseButton = SKLabelNode();
        pauseButton.position = CGPointMake(hud.size.width/1.2, 10);
        pauseButton.text = "||";
        pauseButton.fontSize = hud.size.height * 0.80;
        pauseButton.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.Center;
        pauseButton.name = "PauseButton";
        hud.addChild(pauseButton);
        
        // Display the current score
        self.score = 0;
        self.scoreNode.position = CGPointMake(hud.size.width/2, 5);
        self.scoreNode.text = "0";
        self.scoreNode.fontSize = hud.size.height;
        hud.addChild(self.scoreNode);
    }
    
    override func didMoveToView(view: SKView) {
        background.position = CGPointMake(0, 0);
        background.zPosition = -100;
        
        self.addChild(background);
        
        createHUD();
        
        player = Player();
        player!.position = CGPointMake(self.size.width/2, self.size.height/10);
        self.addChild(player!);
        
        physicsWorld.contactDelegate = self;
        
        playerProjectilesTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(shootingRate), target: self, selector: Selector("shootProjectiles"), userInfo: nil, repeats: true);
        
        enemySpawnTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(enemySpawnRate), target: self, selector: ("spawnBaddies"), userInfo: nil, repeats: true);
        
        if (motionManager.accelerometerAvailable == true) {
            motionManager.accelerometerUpdateInterval = 0.1;
            motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue.currentQueue()!, withHandler:{
                data, error in
                
                let currentX = self.player!.position.x;
                
                self.destX = currentX + CGFloat(data!.acceleration.x * 350);
                
                if(self.destX > self.size.width + self.playingSceneXOffset) {
                    self.destX = self.size.width + self.playingSceneXOffset;
                }
                
                if(self.destX < 0 - self.playingSceneXOffset) {
                    self.destX = 0 - self.playingSceneXOffset;
                }
            });
        } else {
            self.hasAccelerometer = false;
            NSLog("Motion manager not available");
        }
    }
    
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
        
        if(self.score / self.gameDifficulty > 500) {
            self.gameDifficulty++;
            
            if(self.enemySpawnRate > 0.45) {
                self.enemySpawnRate -= ENEMY_SPAWNRATE_DELTA;
                
                NSLog("Speed: %f", self.enemySpawnRate);
                
                enemySpawnTimer?.invalidate();
                enemySpawnTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(enemySpawnRate), target: self, selector: ("spawnBaddies"), userInfo: nil, repeats: true);
            }
        }
        
        if(!self.gamePaused) {
            
            if(!hasAccelerometer) {
                return;
            }
            
            self.player!.move(destX);
        }
    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        if(!self.gamePaused) {
            let bodyA : SKPhysicsBody = contact.bodyA;
            let bodyB : SKPhysicsBody = contact.bodyB;
            
            if (((bodyA.categoryBitMask == Physics.Enemy && bodyB.categoryBitMask == Physics.Projectile)
                || (bodyA.categoryBitMask == Physics.Projectile && bodyB.categoryBitMask == Physics.Enemy))) {
                     collisionWithProjectile(bodyA.node as! SKSpriteNode, bullet: bodyB.node as! SKSpriteNode);
            }
            
            if (bodyA.categoryBitMask == Physics.Enemy && bodyB.categoryBitMask == Physics.Player) {
                collisionWithPlayer(bodyA.node as! SKSpriteNode, player: bodyB.node as! SKSpriteNode);
            } else if (bodyA.categoryBitMask == Physics.Player && bodyB.categoryBitMask == Physics.Enemy) {
                collisionWithPlayer((bodyB.node as? SKSpriteNode)!, player: (bodyA.node as? SKSpriteNode)!);
            }
        }
    }
    
    func collisionWithProjectile(enemy: SKSpriteNode, bullet: SKSpriteNode) {
        // TODO: Add score flash +50 or something
        enemy.removeFromParent();
        bullet.removeFromParent();
        self.score += SCORE_ENEMY;
        
        self.scoreNode.text = "\(score)";
    }
    
    func collisionWithPlayer(enemy: SKSpriteNode, player: SKSpriteNode) {
        // take away 1 life, perform check whether there's more life else go game over
        // play sound
        enemy.removeFromParent();
        
        if(!self.gamePaused) {
            if(self.player!.isInvincible == false) {
                if(self.remainingLives > 0) {
                    self.remainingLives--;
                    self.lifeNodes[remainingLives].alpha = 0.0;
                    self.player!.toggleInvincibility();
                    NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: ("resetInvincibleState"), userInfo: nil, repeats: false);
                    
                    self.player!.pulse();
                }
                
                if(self.remainingLives <= 0) {
                    gameOver();
                }
            }
        }
    }

    func resetInvincibleState() {
        self.player?.toggleInvincibility();
    }
    
    func gameOver() {
        // navigate to game over screen where score is displayed
        self.motionManager.stopAccelerometerUpdates();
        
        self.paused = true;
        let transition:SKTransition = SKTransition.revealWithDirection(SKTransitionDirection.Down, duration: 0.2);
        
        self.view?.presentScene(GameOverScene(size: CGSize(width: self.size.width, height: self.size.height)), transition: transition);
    }
    
    func shootProjectiles(){
        if(!self.gamePaused) {
            let projectile = Projectile(x: self.player!.position.x, y: self.player!.position.y, top: self.size.height);
            self.addChild(projectile);
        }
    }
    
    func spawnBaddies(){
        if(!self.gamePaused) {
            let minX : UInt32 = UInt32(0 - self.playingSceneXOffset);
            let maxX : UInt32 = UInt32((self.size.width) + self.playingSceneXOffset);
            
            let position = CGPoint(x: CGFloat(arc4random_uniform(maxX - minX) + minX), y: self.size.height);
            
            let enemy = Enemy();
            enemy.moveToPos(position);
            
            self.addChild(enemy);
        }
    }
    
    func pauseGame() {
        self.gamePaused = true;
        
        self.paused = true;
        
        let alert = UIAlertController(title: "Game Paused", message: "", preferredStyle: UIAlertControllerStyle.Alert);
        
        alert.addAction(UIAlertAction(title: "Continue", style: UIAlertActionStyle.Default)  { _ in
            self.gamePaused = false;
            self.paused = false;
            });
        
        self.view?.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let location = touch.locationInNode(self);
            
            let node = self.nodeAtPoint(location);
            
            if((node.name == "PauseButton") || (node.name == "PauseButtonContainer")) {
                pauseGame();
            } else {
                
            }
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let location = touch.locationInNode(self)
            
            if(!self.hasAccelerometer) {
                self.player!.move(location.x);
            }
        }
    }
}
