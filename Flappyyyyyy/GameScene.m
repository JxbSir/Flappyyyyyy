//
//  GameScene.m
//  Flappyyyyyy
//
//  Created by Peter on 16/2/1.
//  Copyright (c) https://github.com/JxbSir  All rights reserved.
//

#import "GameScene.h"

#define easyHoleRat     3.0f

#define monkeySize      60
#define monkeyX         250

#define wallWidth       60
#define wallAppearTime  1.5


#define key_readyToFly      @"ReadyToFly"
#define key_addWall         @"AddWall"
#define key_moveWall        @"MoveWall"
#define key_name_upwall     @"upwall"
#define key_name_hole       @"hole"
#define key_name_downwall   @"downwall"

static const uint32_t categoryMonkey = 0x1 << 0;
static const uint32_t categoryWall = 0x1 << 1;
static const uint32_t categoryHole = 0x1 << 2;
static const uint32_t categoryGround = 0x1 << 3;
static const uint32_t categoryEdge = 0x1 << 4;

@protocol RestartSceneDelegate <NSObject>
- (void)restart;
@end

@interface RestartScene : SKSpriteNode
@property(nonatomic, weak  ) id<RestartSceneDelegate> delegate;
@property(nonatomic, strong) SKSpriteNode   *button;
@property(nonatomic, strong) SKLabelNode    *labelNode;

- (void)show:(SKScene*)sc;
@end

@implementation RestartScene
- (id)initWithColor:(UIColor *)color size:(CGSize)size {
    if (self = [super initWithColor:color size:size]) {
        self.userInteractionEnabled = YES;
        
        self.button = [SKSpriteNode spriteNodeWithColor:[UIColor blackColor] size:CGSizeMake(260, 130)];
        self.button.position = CGPointMake(size.width / 2.0f, size.height - 400);
        [self addChild:self.button];
        
        self.labelNode = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
        self.labelNode.text = @"Restart";
        self.labelNode.fontSize = 30.0f;
        self.labelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
        self.labelNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
        self.labelNode.position = CGPointMake(0, 0);
        self.labelNode.fontColor = [UIColor whiteColor];
        [self.button addChild:self.labelNode];
    }
    return self;
}

- (void)show:(SKScene*)sc {
    self.anchorPoint = CGPointMake(0, 0);
    self.alpha = 0.0f;
    [sc addChild:self];
    [self runAction:[SKAction fadeInWithDuration:0.3f]];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    SKNode *touchNode = [self nodeAtPoint:location];
    
    if (touchNode == self.button || touchNode == self.labelNode) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(restart)]) {
            [self.delegate restart];
            [self removeFromParent];
        }
    }

}
@end


@interface GameScene()<SKPhysicsContactDelegate,RestartSceneDelegate>
@property (nonatomic,assign) NSInteger      gamelevel;
@property (nonatomic,assign) CGFloat        defaultY;
@property (nonatomic,strong) SKSpriteNode   *spriteMonkey;
@property (nonatomic,strong) SKLabelNode    *lblPoint;
@property (nonatomic,strong) SKAction       *actionMoveWall;
@property (nonatomic,assign) BOOL           isStarting;
@property (nonatomic,assign) BOOL           isGameOver;
@end

@implementation GameScene

-(void)didMoveToView:(SKView *)view {
    self.backgroundColor = [UIColor blackColor];
    self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
    self.physicsBody.contactTestBitMask = categoryEdge;
    self.physicsWorld.contactDelegate = self;

    self.actionMoveWall = [SKAction moveToX:-wallWidth - 10 duration:5];
    
    self.defaultY = CGRectGetMidY(self.frame);
    
    self.lblPoint = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
    self.lblPoint.text = @"0";
    self.lblPoint.fontSize = 50;
    self.lblPoint.position = CGPointMake(50, CGRectGetMidY(self.frame));
    [self addChild:self.lblPoint];
    
    [self initSpriteMonkey];
}

- (void)initSpriteMonkey {
    self.spriteMonkey = [SKSpriteNode spriteNodeWithImageNamed:@"monkey"];
    self.spriteMonkey.anchorPoint = CGPointMake(0.5, 0.5);
    self.spriteMonkey.size = CGSizeMake(monkeySize, monkeySize);
    self.spriteMonkey.position = CGPointMake(monkeyX, self.defaultY);
    self.spriteMonkey.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:self.spriteMonkey.size center:CGPointMake(0, 0)];
    self.spriteMonkey.physicsBody.affectedByGravity = NO;
    self.spriteMonkey.physicsBody.categoryBitMask = categoryMonkey;
    self.spriteMonkey.physicsBody.collisionBitMask = categoryWall | categoryGround;
    self.spriteMonkey.physicsBody.contactTestBitMask = categoryHole | categoryWall | categoryGround;
    [self addChild:self.spriteMonkey];
    
    [self.spriteMonkey runAction:[SKAction repeatActionForever:[self readyToFly]]
                         withKey:key_readyToFly];
}

/**
 *  准备起飞
 */
- (SKAction *)readyToFly {
    SKAction *flyUp = [SKAction moveToY:self.spriteMonkey.position.y + 10 duration:0.3f];
    flyUp.timingMode = SKActionTimingEaseOut;
    SKAction *flyDown = [SKAction moveToY:self.spriteMonkey.position.y - 10 duration:0.3f];
    flyDown.timingMode = SKActionTimingEaseOut;
    SKAction *fly = [SKAction sequence:@[flyUp, flyDown]];
    return fly;
}

/**
 *  点击开始
 *
 *  @param touches
 *  @param event
 */
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.isGameOver)
        return;
    if (!self.isStarting) {
        self.isStarting = YES;
        [self beginGame];
    }
    [self.spriteMonkey removeAllActions];
    
    self.spriteMonkey.physicsBody.velocity = CGVectorMake(0, 400);
    
    [self playSoundWithName:@"wk_wing.caf"];
}

/**
 *  开始游戏
 */
- (void)beginGame {
    self.spriteMonkey.physicsBody.affectedByGravity = YES;
    SKAction *actionAddWall = [SKAction performSelector:@selector(addWallBlock) onTarget:self];
    SKAction *actionWait = [SKAction waitForDuration:wallAppearTime];
    SKAction *action = [SKAction sequence:@[actionAddWall,actionWait]];
    [self runAction:[SKAction repeatActionForever:action] withKey:key_addWall];
}

/**
 *  添加阻碍
 */
- (void)addWallBlock {
    CGFloat x = self.frame.size.width;
    CGFloat h = self.frame.size.height;
    
    CGFloat hole = monkeySize * easyHoleRat - self.gamelevel;
    CGFloat h_down = arc4random() % (int)(h - hole - 200) + 100;
    CGFloat h_up = h - h_down - hole;

    SKSpriteNode* nodedown = [SKSpriteNode spriteNodeWithImageNamed:@"fire_down"];
    nodedown.size = CGSizeMake(wallWidth, h_down);
    nodedown.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:nodedown.size center:CGPointMake(nodedown.size.width / 2.0f, nodedown.size.height / 2.0f)];
    nodedown.physicsBody.dynamic = NO;
    nodedown.physicsBody.friction = 0;
    nodedown.physicsBody.categoryBitMask = categoryWall;
    nodedown.name = key_name_downwall;
    nodedown.anchorPoint = CGPointMake(0, 0);
    nodedown.position = CGPointMake(x, 0);
    [nodedown runAction:self.actionMoveWall withKey:key_moveWall];
    [self addChild:nodedown];
    
    SKSpriteNode* nodeHole = [SKSpriteNode spriteNodeWithColor:[UIColor blackColor] size:CGSizeMake(wallWidth, hole)];
    nodeHole.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:nodeHole.size center:CGPointMake(nodeHole.size.width / 2.0f, nodeHole.size.height / 2.0f)];
    nodeHole.physicsBody.dynamic = NO;
    nodeHole.physicsBody.friction = 0;
    nodeHole.physicsBody.categoryBitMask = categoryHole;
    nodeHole.name = key_name_hole;
    nodeHole.anchorPoint = CGPointMake(0, 0);
    nodeHole.position = CGPointMake(x, h_down);
    [nodeHole runAction:self.actionMoveWall withKey:key_moveWall];
    [self addChild:nodeHole];
    
    SKSpriteNode* nodeUp = [SKSpriteNode spriteNodeWithImageNamed:@"fire_up"];
    nodeUp.size = CGSizeMake(wallWidth, h_up);
    nodeUp.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:nodeUp.size center:CGPointMake(nodeUp.size.width / 2.0f, nodeUp.size.height / 2.0f)];
    nodeUp.physicsBody.dynamic = NO;
    nodeUp.physicsBody.friction = 0;
    nodeUp.physicsBody.categoryBitMask = categoryWall;
    nodeUp.name = key_name_upwall;
    nodeUp.anchorPoint = CGPointMake(0, 0);
    nodeUp.position = CGPointMake(x, h - h_up);
    [nodeUp runAction:self.actionMoveWall withKey:key_moveWall];
    [self addChild:nodeUp];
}

/**
 *  每秒计时
 *
 *  @param currentTime
 */
-(void)update:(CFTimeInterval)currentTime {
    //移除已经过期的下面wall
    [self enumerateChildNodesWithName:key_name_downwall usingBlock:^(SKNode * _Nonnull node, BOOL * _Nonnull stop) {
        if (node.frame.origin.x <= -wallWidth) {
            [node removeFromParent];
        }
    }];
    //移除已经过期的上面wall
    [self enumerateChildNodesWithName:key_name_upwall usingBlock:^(SKNode * _Nonnull node, BOOL * _Nonnull stop) {
        if (node.frame.origin.x <= -wallWidth) {
            [node removeFromParent];
        }
    }];
}

#pragma mark - delegate 
- (void)didBeginContact:(SKPhysicsContact *)contact {
    if (self.isGameOver)
        return;
    if ((contact.bodyA.categoryBitMask & categoryMonkey) && (contact.bodyB.categoryBitMask & categoryHole)) {
        // goto hole
    }
    else {
        [self playSoundWithName:@"wk_hit.caf"];
        
        RestartScene* rs = [[RestartScene alloc] initWithColor:[UIColor redColor] size:self.frame.size];
        rs.delegate = self;
        [rs show:self];
        
        self.isGameOver = YES;
        [self removeActionForKey:key_addWall];
        
        [self enumerateChildNodesWithName:key_name_upwall usingBlock:^(SKNode *node, BOOL *stop) {
            [node removeActionForKey:key_moveWall];
        }];
        [self enumerateChildNodesWithName:key_name_downwall usingBlock:^(SKNode *node, BOOL *stop) {
            [node removeActionForKey:key_moveWall];
        }];
    }
}

- (void)didEndContact:(SKPhysicsContact *)contact {
    if (self.isGameOver)
        return;
    if ((contact.bodyA.categoryBitMask & categoryMonkey) && (contact.bodyB.categoryBitMask & categoryHole)) {
        NSLog(@"%@",@"good luck, you sucess");
        self.gamelevel ++;
        self.lblPoint.text = [NSString stringWithFormat:@"%ld",(long)self.gamelevel];
        [self playSoundWithName:@"wk_point.caf"];
    }
}

- (void)playSoundWithName:(NSString *)fileName {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self runAction:[SKAction playSoundFileNamed:fileName waitForCompletion:YES]];
    });
}

- (void)restart {
    self.isStarting = NO;
    self.isGameOver = NO;
    self.gamelevel = 0;
    self.lblPoint.text = @"0";
    
    [self enumerateChildNodesWithName:key_name_downwall usingBlock:^(SKNode *node, BOOL *stop) {
        [node removeFromParent];
    }];
    
    [self enumerateChildNodesWithName:key_name_hole usingBlock:^(SKNode *node, BOOL *stop) {
        [node removeFromParent];
    }];
    
    [self enumerateChildNodesWithName:key_name_upwall usingBlock:^(SKNode *node, BOOL *stop) {
        [node removeFromParent];
    }];
    
    [self.spriteMonkey removeFromParent];
    [self initSpriteMonkey];
}
@end
