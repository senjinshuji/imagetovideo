const https = require('https');

class OpenAIImageGenerator {
    constructor() {
        this.apiKey = process.env.OPENAI_API_KEY || 'YOUR_OPENAI_API_KEY';
    }

    async generateImage(prompt, size = "1024x1024") {
        return new Promise((resolve, reject) => {
            const data = JSON.stringify({
                model: "gpt-image-1",
                prompt: prompt,
                n: 1,
                size: size
            });

            const options = {
                hostname: 'api.openai.com',
                port: 443,
                path: '/v1/images/generations',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Length': data.length
                }
            };

            const req = https.request(options, (res) => {
                let responseData = '';

                res.on('data', (chunk) => {
                    responseData += chunk;
                });

                res.on('end', () => {
                    if (res.statusCode === 200) {
                        try {
                            const result = JSON.parse(responseData);
                            resolve(result);
                        } catch (error) {
                            reject(new Error('Failed to parse response'));
                        }
                    } else {
                        reject(new Error(`API request failed with status ${res.statusCode}: ${responseData}`));
                    }
                });
            });

            req.on('error', (error) => {
                reject(error);
            });

            req.write(data);
            req.end();
        });
    }

    // 画像URLをファイルに保存
    async saveImageFromUrl(imageUrl, filename = 'generated-image.png') {
        const https = require('https');
        const fs = require('fs');
        
        return new Promise((resolve, reject) => {
            const file = fs.createWriteStream(filename);
            
            https.get(imageUrl, (response) => {
                response.pipe(file);
                
                file.on('finish', () => {
                    file.close();
                    resolve(filename);
                });
                
                file.on('error', (err) => {
                    fs.unlink(filename, () => {});
                    reject(err);
                });
            }).on('error', (err) => {
                reject(err);
            });
        });
    }
    
    // Base64画像データをファイルに保存
    saveBase64Image(base64Data, filename = 'generated-image.png') {
        const fs = require('fs');
        const buffer = Buffer.from(base64Data, 'base64');
        fs.writeFileSync(filename, buffer);
        return filename;
    }
}

module.exports = OpenAIImageGenerator;

// 使用例
async function example() {
    const generator = new OpenAIImageGenerator();
    
    try {
        const result = await generator.generateImage("A beautiful landscape with mountains and a lake");
        
        if (result.data && result.data[0]) {
            const filename = generator.saveBase64Image(result.data[0].b64_json);
            console.log(`Image saved as: ${filename}`);
            return filename;
        }
    } catch (error) {
        console.error('Image generation failed:', error.message);
    }
}

// 直接実行時の処理
if (require.main === module) {
    example().catch(console.error);
}