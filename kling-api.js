const jwt = require('jsonwebtoken');
const axios = require('axios');

class KlingVideoGenerator {
    constructor() {
        this.accessKey = process.env.KLING_ACCESS_KEY || 'At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf';
        this.secretKey = process.env.KLING_SECRET_KEY || 'pJent9rFbmCHGDYndk3dmMyG4PHyagL8';
        this.baseUrl = 'https://api-singapore.klingai.com/v1';
    }

    generateJWT() {
        const payload = {
            iss: this.accessKey,
            exp: Math.floor(Date.now() / 1000) + 1800, // 30分有効
            nbf: Math.floor(Date.now() / 1000) - 5      // 5秒前から有効
        };

        return jwt.sign(payload, this.secretKey, { 
            algorithm: 'HS256',
            header: { alg: 'HS256', typ: 'JWT' }
        });
    }

    async generateVideo(imageUrl, prompt, duration = 5) {
        const token = this.generateJWT();
        
        const headers = {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        };

        const data = {
            model: 'kling-v1',
            image: imageUrl,
            prompt: prompt,
            duration: '5',  // 文字列として送信
            aspect_ratio: '16:9',
            cfg_scale: 0.5,
            mode: 'std'
        };

        try {
            const response = await axios.post(
                `${this.baseUrl}/videos/image2video`,
                data,
                { headers }
            );
            
            return response.data;
        } catch (error) {
            console.error('Error generating video:', error.response?.data || error.message);
            throw error;
        }
    }

    async checkTaskStatus(taskId) {
        const token = this.generateJWT();
        
        const headers = {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        };

        try {
            const response = await axios.get(
                `${this.baseUrl}/videos/image2video/${taskId}`,
                { headers }
            );
            
            return response.data;
        } catch (error) {
            console.error('Error checking task status:', error.response?.data || error.message);
            throw error;
        }
    }

    async waitForCompletion(taskId, maxWaitSeconds = 300) {
        const startTime = Date.now();
        const maxWaitMs = maxWaitSeconds * 1000;

        while (Date.now() - startTime < maxWaitMs) {
            try {
                const result = await this.checkTaskStatus(taskId);
                
                if (result.data.task_status === 'succeed') {
                    return result.data.works[0].url;
                } else if (result.data.task_status === 'failed') {
                    throw new Error(`Video generation failed: ${result.data.task_status_msg || 'Unknown error'}`);
                }
                
                console.log(`Task status: ${result.data.task_status}, waiting...`);
                await this.sleep(10000); // 10秒待機
                
            } catch (error) {
                console.error('Error while waiting for completion:', error.message);
                throw error;
            }
        }
        
        throw new Error('Timeout waiting for video generation completion');
    }

    async generateVideoWithRetry(imageUrl, prompt, duration = 5, maxRetries = 3) {
        for (let attempt = 0; attempt < maxRetries; attempt++) {
            try {
                return await this.generateVideo(imageUrl, prompt, duration);
            } catch (error) {
                if (attempt === maxRetries - 1) {
                    throw error;
                }
                
                // 指数バックオフ
                const waitTime = (Math.pow(2, attempt) + Math.random()) * 1000;
                console.log(`Attempt ${attempt + 1} failed, retrying in ${waitTime}ms...`);
                await this.sleep(waitTime);
            }
        }
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    // 完全なワークフロー実行
    async processImageToVideo(imageUrl, prompt, duration = 5) {
        console.log('Starting video generation...');
        
        try {
            // 動画生成開始
            const result = await this.generateVideoWithRetry(imageUrl, prompt, duration);
            
            if (result.code !== 0) {
                throw new Error(`API error: ${result.message}`);
            }
            
            const taskId = result.data.task_id;
            console.log(`Task created with ID: ${taskId}`);
            
            // 完了まで待機
            const videoUrl = await this.waitForCompletion(taskId);
            console.log(`Video generation completed: ${videoUrl}`);
            
            return {
                success: true,
                taskId: taskId,
                videoUrl: videoUrl
            };
            
        } catch (error) {
            console.error('Video generation process failed:', error.message);
            return {
                success: false,
                error: error.message
            };
        }
    }
}

module.exports = KlingVideoGenerator;

// 使用例
async function example() {
    const generator = new KlingVideoGenerator();
    
    const result = await generator.processImageToVideo(
        'https://example.com/image.jpg',
        'カメラが左から右にパンしながら、美しい風景を映す',
        5
    );
    
    if (result.success) {
        console.log('Success!', result);
    } else {
        console.log('Failed:', result.error);
    }
}

// 直接実行時の処理
if (require.main === module) {
    example().catch(console.error);
}